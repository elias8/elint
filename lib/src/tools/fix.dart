// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:analysis_server_plugin/edit/change_builder/change_builder.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/fix/dart_fix_context.dart';
import 'package:analysis_server_plugin/src/correction/dart_change_workspace.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/file_system/file_system.dart' as analyzer_fs;
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/instrumentation/service.dart';
import 'package:analyzer/src/analysis_options/analysis_options.dart';
import 'package:analyzer/src/analysis_rule/rule_context.dart';
import 'package:analyzer/src/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/src/dart/analysis/driver_based_analysis_context.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/dart/element/type_system.dart';
import 'package:analyzer/src/ignore_comments/ignore_info.dart';
import 'package:analyzer/src/lint/linter_visitor.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';

import '../catalog.dart';
import '../rules/sort_member_order/member_order_config.dart';
import '../rules/sort_member_order/sort_member_order.dart';

/// Analyzes [workingDirectory] or [FixRequest.target] and computes fixes.
///
/// Pass an absolute [workingDirectory]. In [FixMode.dryRun], this function
/// writes no files. In [FixMode.apply], it writes after convergence and checks
/// that each changed file still has its original contents. The writes are not
/// atomic across files, so an I/O error can leave earlier files written.
/// Errors from analysis and file access propagate. [ArgumentError] reports an
/// invalid target. [FormatException] reports an invalid selected rule
/// configuration. [StateError] reports non-convergence or a changed file.
Future<FixResult> runFixes(
  FixRequest request, {
  required String workingDirectory,
}) async {
  final runner = _BatchFixRunner(request, workingDirectory);
  final result = await runner.run();
  if (request.mode == FixMode.apply) await runner.apply(result);
  return result;
}

/// Describes a selected diagnostic that remains after the fix run.
///
/// [line] and [column] are one-based. [hasFix] is true when the rule registers
/// a fix producer.
final class const FixDiagnostic({
  required final String path,
  required final String code,
  required final String message,
  required final int line,
  required final int column,
  required final bool hasFix,
});

/// Holds the original and proposed contents of one changed file.
final class const FixFileChange({
  required final String path,
  required final String before,
  required final String after,
});

/// Selects whether [runFixes] writes the proposed changes.
enum FixMode() {
  apply,
  dryRun,
}

/// Describes one batch fix run.
///
/// Codes and groups use separate namespaces. Selectors ignore case, and codes
/// accept the `elint/` prefix. Explicit selectors union their rules and enable
/// them even when the target disables them. An empty selection uses the rules
/// enabled by the target project's analyzer configuration. An empty or unknown
/// selector throws [FormatException].
///
/// If [target] is null, [runFixes] analyzes the `workingDirectory` value it
/// receives.
/// A relative target resolves against that directory.
final class FixRequest({
  required final FixMode mode,
  Iterable<String> codes = const [],
  Iterable<String> groups = const [],
  final String? target,
}) {
  final Set<String> selectedCodes = Set.unmodifiable(
    _resolveSelectors(codes, groups),
  );

  static Set<String> _resolveSelectors(
    Iterable<String> codes,
    Iterable<String> groups,
  ) {
    final selected = <String>{};
    for (final value in codes) {
      final code = value.trim();
      if (code.isEmpty) {
        throw const FormatException('Empty lint code.');
      }
      final normalized = ElintCatalog.normalizeCode(code);
      if (!ElintCatalog.byCode.containsKey(normalized)) {
        throw FormatException('Unknown elint code: $code');
      }
      selected.add(normalized);
    }
    for (final value in groups) {
      final group = value.trim().toLowerCase();
      if (group.isEmpty) {
        throw const FormatException('Empty lint group.');
      }
      final groupCodes = ElintCatalog.groups[group];
      if (groupCodes == null) {
        throw FormatException('Unknown elint group: $value');
      }
      selected.addAll(groupCodes);
    }
    return selected;
  }
}

/// Contains the immutable result of a fix run.
///
/// [converged] means no more compatible fixes were available. Residual
/// diagnostics can remain, including diagnostics without fix producers.
/// [fixesByCode] counts accepted proposals by lint code.
final class FixResult({
  required final FixMode mode,
  required final bool converged,
  required Iterable<FixFileChange> changes,
  required Iterable<FixDiagnostic> remainingDiagnostics,
  required Map<String, int> fixesByCode,
}) {
  final List<FixFileChange> changes = List.unmodifiable(changes);
  final List<FixDiagnostic> remainingDiagnostics = List.unmodifiable(
    remainingDiagnostics,
  );
  final Map<String, int> fixesByCode = Map.unmodifiable(fixesByCode);
}

final class _BatchFixRunner(
  final FixRequest request,
  final String workingDirectory,
) {
  final resources = OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);
  final Map<String, String> originalContents = {};
  final Map<String, String> overlayContents = {};

  Future<void> apply(FixResult result) async {
    if (!result.converged) {
      throw StateError('Fixes did not converge; no files were written.');
    }
    for (final change in result.changes) {
      final disk = File(change.path).readAsStringSync();
      if (disk != change.before) {
        throw StateError(
          'File changed during fix run; no files were written: ${change.path}',
        );
      }
    }
    for (final change in result.changes) {
      File(change.path).writeAsStringSync(change.after);
    }
  }

  Future<FixResult> run() async {
    final targetArgument = request.target ?? workingDirectory;
    final absoluteArgument = resources.pathContext.isAbsolute(targetArgument)
        ? targetArgument
        : resources.pathContext.join(workingDirectory, targetArgument);
    final targetPath = resources.pathContext.normalize(absoluteArgument);
    final targetType = FileSystemEntity.typeSync(targetPath);
    final isFile = targetType == FileSystemEntityType.file;
    if (!isFile && targetType != FileSystemEntityType.directory) {
      throw ArgumentError('Target does not exist: $targetPath');
    }
    final includedPath = isFile
        ? resources.pathContext.dirname(targetPath)
        : targetPath;
    final collection = AnalysisContextCollectionImpl(
      resourceProvider: resources,
      includedPaths: [includedPath],
      configureAnalysisOptionsBuilder: ({required analysisOptionsBuilder}) {
        analysisOptionsBuilder
          ..warning = false
          ..lint = false;
      },
    );
    try {
      final targetFiles = isFile
          ? [targetPath]
          : collection.contexts
                .expand((context) => context.contextRoot.analyzedFiles())
                .where((path) {
                  return path.endsWith('.dart') &&
                      resources.pathContext.isWithin(targetPath, path);
                })
                .toSet();
      final analyzedTargets = targetFiles.where((path) {
        return collection.contexts.any(
          (context) => context.contextRoot.isAnalyzed(path),
        );
      }).toSet();
      for (final path in analyzedTargets) {
        originalContents[path] = File(path).readAsStringSync();
      }
      _validateMemberOrderOptions(collection, analyzedTargets);
      return await _converge(collection, analyzedTargets);
    } finally {
      await collection.dispose();
    }
  }

  Map<String, String> _changedContents() => {
    for (final entry in overlayContents.entries)
      if (entry.value != originalContents[entry.key]) entry.key: entry.value,
  };

  int _compareEdit(_ProposedEdit a, _ProposedEdit b) {
    final pathOrder = a.path.compareTo(b.path);
    if (pathOrder != 0) return pathOrder;
    return a.edit.offset.compareTo(b.edit.offset);
  }

  List<_Proposal> _compatibleProposals(List<_Proposal> proposals) {
    final ordered = [...proposals]
      ..sort((a, b) {
        final aEdit = a.edits.reduce((x, y) => _compareEdit(x, y) <= 0 ? x : y);
        final bEdit = b.edits.reduce((x, y) => _compareEdit(x, y) <= 0 ? x : y);
        return _compareEdit(aEdit, bEdit);
      });
    final accepted = <_Proposal>[];
    final occupied = <String, List<SourceEdit>>{};
    for (final proposal in ordered) {
      final candidateByPath = <String, List<SourceEdit>>{};
      for (final proposed in proposal.edits) {
        candidateByPath.putIfAbsent(proposed.path, () => []).add(proposed.edit);
      }
      var conflicts = false;
      for (final entry in candidateByPath.entries) {
        final candidate = [...entry.value]
          ..sort((a, b) => a.offset.compareTo(b.offset));
        if (_hasOverlaps(candidate) ||
            _hasOverlaps([
              ...(occupied[entry.key] ?? const []),
              ...candidate,
            ])) {
          conflicts = true;
          break;
        }
      }
      if (conflicts) continue;
      accepted.add(proposal);
      for (final entry in candidateByPath.entries) {
        occupied.putIfAbsent(entry.key, () => []).addAll(entry.value);
      }
    }
    return accepted;
  }

  Future<FixResult> _converge(
    AnalysisContextCollectionImpl collection,
    Set<String> targets,
  ) async {
    const maxPasses = 10;
    final changesByCode = <String, int>{};
    final seenStates = <String>{_stateKey()};
    var pass = 0;
    while (pass < maxPasses) {
      final diagnostics = await _diagnostics(collection, targets);
      final proposals = await _proposals(collection, targets, diagnostics);
      final accepted = _compatibleProposals(proposals);
      if (accepted.isEmpty) {
        return _result(
          _changedContents(),
          _rows(diagnostics),
          changesByCode,
          converged: true,
        );
      }

      final editsByFile = <String, List<SourceEdit>>{};
      for (final proposal in accepted) {
        for (final proposalEdit in proposal.edits) {
          editsByFile
              .putIfAbsent(proposalEdit.path, () => [])
              .add(proposalEdit.edit);
        }
      }
      var contentChanged = false;
      final changedPaths = <String>{};
      for (final entry in editsByFile.entries) {
        final original =
            overlayContents[entry.key] ?? originalContents[entry.key];
        if (original == null) {
          throw StateError(
            'Fix attempted to edit a file outside the target: ${entry.key}',
          );
        }
        final uniqueEdits = <String, SourceEdit>{};
        for (final edit in entry.value) {
          uniqueEdits['${edit.offset}:${edit.length}:${edit.replacement}'] =
              edit;
        }
        final edits = uniqueEdits.values.toList()
          ..sort((a, b) => b.offset.compareTo(a.offset));
        var updated = original;
        for (final edit in edits) {
          if (edit.offset < 0 ||
              edit.length < 0 ||
              edit.offset + edit.length > original.length) {
            throw StateError(
              'Fix returned an invalid source range in ${entry.key}',
            );
          }
          updated = updated.replaceRange(
            edit.offset,
            edit.offset + edit.length,
            edit.replacement,
          );
        }
        if (updated != original) {
          overlayContents[entry.key] = updated;
          changedPaths.add(entry.key);
          contentChanged = true;
        }
      }
      if (!contentChanged) {
        return _result(
          _changedContents(),
          _rows(await _diagnostics(collection, targets)),
          changesByCode,
          converged: true,
        );
      }
      for (final proposal in accepted) {
        changesByCode.update(
          proposal.code,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      for (final path in changedPaths) {
        resources.setOverlay(
          path,
          content: overlayContents[path]!,
          modificationStamp: DateTime.now().millisecondsSinceEpoch + pass + 1,
        );
        for (final context in collection.contexts) {
          context.changeFile(path);
        }
      }
      for (final context in collection.contexts) {
        await context.applyPendingFileChanges();
      }
      pass++;
      final state = _stateKey();
      if (!seenStates.add(state)) {
        return _result(
          _changedContents(),
          _rows(await _diagnostics(collection, targets)),
          changesByCode,
          converged: false,
        );
      }
    }

    return _result(
      _changedContents(),
      _rows(await _diagnostics(collection, targets)),
      changesByCode,
      converged: false,
    );
  }

  Future<List<_RuleDiagnostic>> _diagnostics(
    AnalysisContextCollectionImpl collection,
    Set<String> targets,
  ) async {
    final libraries = <({DriverBasedAnalysisContext context, String path})>{};
    for (final path in targets) {
      final context = collection.contextFor(path);
      if (!context.contextRoot.isAnalyzed(path)) continue;
      final result = await context.currentSession.getResolvedUnit(path);
      if (result is! ResolvedUnitResult) continue;
      final libraryPath = result.libraryElement.firstFragment.source.fullName;
      libraries.add((context: context, path: libraryPath));
    }

    final diagnostics = <_RuleDiagnostic>[];
    final orderedLibraries = libraries.toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final library in orderedLibraries) {
      final result = await library.context.currentSession.getResolvedLibrary(
        library.path,
      );
      if (result is! ResolvedLibraryResult) continue;
      final resolvedContext = _resolvedContext(library.context, result);
      if (resolvedContext == null) continue;
      final context = resolvedContext.context;
      final enabledByUnit = {
        for (final unit in context.allUnits)
          unit: library.context.contextRoot.isAnalyzed(unit.file.path)
              ? _selectedFor(library.context, unit.file).toSet()
              : <ElintRuleSpec>{},
      };
      final libraryRules = enabledByUnit.values
          .expand((rules) => rules)
          .toSet();
      if (libraryRules.isEmpty) continue;
      final registry = RuleVisitorRegistryImpl(enableTiming: false);
      final rules = [for (final spec in libraryRules) spec.rule()];
      for (final rule in rules) {
        rule.registerNodeProcessors(registry, context);
      }
      for (final unit in context.allUnits) {
        if (!library.context.contextRoot.isAnalyzed(unit.file.path)) continue;
        for (final rule in rules) {
          rule.reporter = unit.diagnosticReporter;
        }
        context.currentUnit = unit;
        unit.unit.accept(
          AnalysisRuleVisitor(registry, shouldPropagateExceptions: true),
        );
      }
      context.currentUnit = context.definingUnit;
      AnalysisRuleVisitor(registry).afterLibrary();
      for (final entry in resolvedContext.listeners.entries) {
        if (!targets.contains(entry.key.file.path)) continue;
        final ignoreInfo = IgnoreInfo.forDart(
          entry.key.unit,
          entry.key.content,
        );
        for (final diagnostic in entry.value.diagnostics) {
          final code = ElintCatalog.normalizeCode(
            diagnostic.diagnosticCode.lowerCaseName,
          );
          final spec = ElintCatalog.byCode[code];
          if (spec == null || !enabledByUnit[entry.key]!.contains(spec)) {
            continue;
          }
          if (ignoreInfo.ignored(diagnostic, pluginName: 'elint')) continue;
          final location = entry.key.unit.lineInfo.getLocation(
            diagnostic.offset,
          );
          diagnostics.add(
            _RuleDiagnostic(
              entry.key.file.path,
              diagnostic,
              spec,
              location.lineNumber,
              location.columnNumber,
            ),
          );
        }
      }
    }
    diagnostics.sort((a, b) {
      final byPath = a.path.compareTo(b.path);
      if (byPath != 0) return byPath;
      final byOffset = a.diagnostic.offset.compareTo(b.diagnostic.offset);
      if (byOffset != 0) return byOffset;
      return a.spec.code.compareTo(b.spec.code);
    });
    return diagnostics;
  }

  bool _hasOverlaps(List<SourceEdit> edits) {
    final ordered = [...edits]..sort((a, b) => a.offset.compareTo(b.offset));
    for (var index = 1; index < ordered.length; index++) {
      final previous = ordered[index - 1];
      final current = ordered[index];
      final identical =
          previous.offset == current.offset &&
          previous.length == current.length &&
          previous.replacement == current.replacement;
      if (identical) continue;
      if (current.offset < previous.offset + previous.length ||
          (current.offset == previous.offset &&
              (current.length == 0 || previous.length == 0))) {
        return true;
      }
    }
    return false;
  }

  Future<List<_Proposal>> _proposals(
    AnalysisContextCollectionImpl collection,
    Set<String> targets,
    List<_RuleDiagnostic> diagnostics,
  ) async {
    final sessions = collection.contexts
        .map((context) => context.currentSession)
        .toList();
    final workspace = DartChangeWorkspace(sessions);
    final proposals = <_Proposal>[];
    for (final item in diagnostics) {
      final factory = item.spec.fix;
      if (factory == null) continue;
      final context = collection.contextFor(item.path);
      final unit = await context.currentSession.getResolvedUnit(item.path);
      if (unit is! ResolvedUnitResult) continue;
      final result = await context.currentSession.getResolvedLibrary(
        unit.libraryElement.firstFragment.source.fullName,
      );
      if (result is! ResolvedLibraryResult) continue;
      final unitResult = result.units.firstWhere(
        (unit) => unit.path == item.path,
      );
      final dartFixContext = DartFixContext(
        instrumentationService: InstrumentationService.NULL_SERVICE,
        workspace: workspace,
        libraryResult: result,
        unitResult: unitResult,
        error: item.diagnostic,
      );
      final producerContext = CorrectionProducerContext.createResolved(
        libraryResult: result,
        unitResult: unitResult,
        dartFixContext: dartFixContext,
        diagnostic: item.diagnostic,
        selectionOffset: item.diagnostic.offset,
        selectionLength: item.diagnostic.length,
        applyingBulkFixes: true,
      );
      final producer = factory(context: producerContext);
      final builder = ChangeBuilder(
        workspace: workspace,
        defaultEol: unitResult.content.contains('\r\n') ? '\r\n' : '\n',
      );
      await producer.compute(builder);
      final edits = <_ProposedEdit>[];
      for (final fileEdit in builder.sourceChange.edits) {
        final path = File(fileEdit.file).absolute.path;
        if (!targets.contains(path)) {
          throw StateError(
            'Fix attempted to edit a file outside the target: $path',
          );
        }
        for (final edit in fileEdit.edits) {
          edits.add(_ProposedEdit(path, edit));
        }
      }
      if (edits.isNotEmpty) proposals.add(_Proposal(item.spec.code, edits));
    }
    return proposals;
  }

  _ResolvedRuleContext? _resolvedContext(
    DriverBasedAnalysisContext analysisContext,
    ResolvedLibraryResult libraryResult,
  ) {
    final allUnits = <RuleContextUnit>[];
    final listeners = <RuleContextUnit, RecordingDiagnosticListener>{};
    RuleContextUnit? definingContextUnit;
    final definingUnit =
        (libraryResult.element as LibraryElementImpl).firstFragment;
    for (final unitResult in libraryResult.units) {
      final listener = RecordingDiagnosticListener();
      final unit = RuleContextUnit(
        file: unitResult.file,
        content: unitResult.content,
        diagnosticReporter: DiagnosticReporter(
          listener,
          unitResult.libraryElement.firstFragment.source,
        ),
        unit: unitResult.unit,
      );
      allUnits.add(unit);
      listeners[unit] = listener;
      if (unitResult.unit.declaredFragment == definingUnit) {
        definingContextUnit = unit;
      }
    }
    definingContextUnit ??= allUnits.firstOrNull;
    if (definingContextUnit == null) return null;
    final definingPath = libraryResult.element.firstFragment.source.fullName;
    return _ResolvedRuleContext(
      RuleContextWithResolvedResults(
        allUnits,
        definingContextUnit,
        libraryResult.element.typeProvider,
        libraryResult.element.typeSystem as TypeSystemImpl,
        analysisContext.contextRoot.workspace.findPackageFor(definingPath),
      ),
      listeners,
    );
  }

  FixResult _result(
    Map<String, String> changedContents,
    List<FixDiagnostic> remainingDiagnostics,
    Map<String, int> fixesByCode, {
    required bool converged,
  }) => FixResult(
    mode: request.mode,
    converged: converged,
    changes: [
      for (final entry in changedContents.entries)
        FixFileChange(
          path: entry.key,
          before: originalContents[entry.key]!,
          after: entry.value,
        ),
    ],
    remainingDiagnostics: remainingDiagnostics,
    fixesByCode: fixesByCode,
  );

  List<FixDiagnostic> _rows(List<_RuleDiagnostic> diagnostics) => [
    for (final item in diagnostics)
      FixDiagnostic(
        path: item.path,
        code: item.spec.code,
        message: item.diagnostic.problemMessage.messageText(includeUrl: false),
        line: item.line,
        column: item.column,
        hasFix: item.spec.fix != null,
      ),
  ];

  List<ElintRuleSpec> _selectedFor(
    DriverBasedAnalysisContext context,
    analyzer_fs.File file,
  ) {
    if (request.selectedCodes.isNotEmpty) {
      return request.selectedCodes
          .map((code) => ElintCatalog.byCode[code]!)
          .toList();
    }
    final options =
        context.getAnalysisOptionsForFile(file) as AnalysisOptionsImpl;
    final plugin = options.pluginConfigurations.where(
      (configuration) => configuration.name.toLowerCase() == 'elint',
    );
    final configuration = plugin.firstOrNull;
    if (configuration == null || !configuration.isEnabled) return const [];
    final configs = {
      for (final entry in configuration.diagnosticConfigs.entries)
        entry.key.toLowerCase(): entry.value,
    };
    return ElintCatalog.rules.where((spec) {
      final name = spec.rule().name.toLowerCase();
      return configs[name]?.isEnabled ?? false;
    }).toList();
  }

  void _validateMemberOrderOptions(
    AnalysisContextCollectionImpl collection,
    Set<String> targets,
  ) {
    for (final path in targets) {
      final context = collection.contextFor(path);
      final file = resources.getFile(path);
      final selected = _selectedFor(context, file);
      if (!selected.any(
        (spec) => spec.code == SortMemberOrder.code.lowerCaseName,
      )) {
        continue;
      }
      final result = loadMemberOrderOptions(resources, path);
      if (result case InvalidMemberOrderOptions(
        :final filePath,
        :final optionPath,
        :final message,
      )) {
        throw FormatException(
          'Invalid member-order configuration in $filePath '
          '($optionPath): $message',
        );
      }
    }
  }

  String _stateKey() {
    final entries = overlayContents.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((entry) => '${entry.key}\u0000${entry.value}')
        .join('\u0001');
  }
}

final class const _Proposal(final String code, final List<_ProposedEdit> edits);

final class const _ProposedEdit(final String path, final SourceEdit edit);

final class const _ResolvedRuleContext(
  final RuleContextWithResolvedResults context,
  final Map<RuleContextUnit, RecordingDiagnosticListener> listeners,
);

final class const _RuleDiagnostic(
  final String path,
  final Diagnostic diagnostic,
  final ElintRuleSpec spec,
  final int line,
  final int column,
);
