import 'package:args/command_runner.dart';

import '../../tools.dart';

import '../catalog.dart';

final class const CliResult(final int exitCode, final String output);

Future<CliResult> runElintCommand(
  List<String> args, {
  required String workingDirectory,
}) async {
  final runner = _ElintCommandRunner(workingDirectory);
  try {
    return await runner.run(args) ?? CliResult(0, runner.output.toString());
  } on UsageException catch (error) {
    return CliResult(2, '$error\n');
  }
}

final class _ElintCommandRunner(String workingDirectory)
    extends CommandRunner<CliResult> {
  final output = StringBuffer();

  this : super('elint', 'Analyze and fix elint diagnostics.') {
    addCommand(_FixCommand(workingDirectory, output));
  }

  @override
  void printUsage() => output.writeln(usage);
}

final class _FixCommand(
  final String workingDirectory,
  final StringBuffer output,
) extends Command<CliResult> {
  this {
    argParser
      ..addFlag('apply', negatable: false, help: 'Apply the selected fixes.')
      ..addFlag(
        'dry-run',
        abbr: 'n',
        negatable: false,
        help: 'Preview the selected fixes without writing files.',
      )
      ..addMultiOption(
        'code',
        help: 'Select lint codes, repeated or comma-separated.',
      )
      ..addMultiOption(
        'group',
        help: 'Select lint groups, repeated or comma-separated.',
      );
  }

  @override
  String get name => 'fix';

  @override
  String get description => 'Apply or preview fixes for elint diagnostics.';

  @override
  String get invocation => '${super.invocation} [directory|file]';

  @override
  String get usageFooter {
    final codes = ElintCatalog.rules.map((rule) => rule.code).toList()..sort();
    final groups = ElintCatalog.groups.entries.map((entry) {
      final codes = entry.value.toList()..sort();
      return '${entry.key} (${codes.join(', ')})';
    }).toList()..sort();
    return 'Without selectors, fixes workspace-enabled elint rules. '
        'With selectors, fixes only their union, including rules disabled '
        'in analysis options.\n\n'
        'Groups: ${groups.join('; ')}\nCodes: ${codes.join(', ')}';
  }

  @override
  void printUsage() => output.writeln(usage);

  @override
  Future<CliResult> run() async {
    final results = argResults!;
    final apply = results.flag('apply');
    final dryRun = results.flag('dry-run');
    if (apply == dryRun) usageException('Choose either --apply or --dry-run.');
    if (results.rest.length > 1) usageException('Expected at most one target.');

    final codes = results.multiOption('code');
    if (codes.any((value) => value.trim().isEmpty)) {
      usageException('Empty selector for --code.');
    }
    final groups = results.multiOption('group');
    if (groups.any((value) => value.trim().isEmpty)) {
      usageException('Empty selector for --group.');
    }

    late final FixRequest request;
    try {
      request = FixRequest(
        mode: apply ? FixMode.apply : FixMode.dryRun,
        codes: codes,
        groups: groups,
        target: results.rest.singleOrNull,
      );
    } on FormatException catch (error) {
      usageException(error.message);
    }

    try {
      final result = await runFixes(
        request,
        workingDirectory: workingDirectory,
      );
      return CliResult(result.converged ? 0 : 2, _renderReport(result));
    } on Object catch (error) {
      return CliResult(2, 'elint fix failed: $error\n');
    }
  }
}

String _renderReport(FixResult result) {
  final changedFiles = result.changes.length;
  final noFix = result.remainingDiagnostics.where((row) => !row.hasFix).length;
  final fixesByCode = result.fixesByCode.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join(', ');
  final buffer = StringBuffer()
    ..writeln(
      'Files changed: ${result.mode == FixMode.apply ? changedFiles : 0}',
    )
    ..writeln('Fixable files: $changedFiles')
    ..writeln('Codes fixed: ${result.fixesByCode.length}')
    ..writeln('Fixes by code: $fixesByCode')
    ..writeln(
      'Remaining selected diagnostics: ${result.remainingDiagnostics.length}',
    )
    ..writeln('Remaining diagnostics without fixes: $noFix')
    ..writeln('No changes: ${changedFiles == 0 ? 'yes' : 'no'}')
    ..writeln('Status: ${result.converged ? 'converged' : 'did not converge'}');
  if (result.mode == FixMode.dryRun) buffer.write(_renderDiff(result.changes));
  if (result.remainingDiagnostics.isNotEmpty) {
    for (final row in result.remainingDiagnostics) {
      buffer.writeln(
        '${row.path}:${row.line}:${row.column}: ${row.code}: ${row.message}',
      );
    }
  }
  return buffer.toString();
}

String _renderDiff(List<FixFileChange> changes) {
  final buffer = StringBuffer();
  for (final change
      in changes.toList()..sort((a, b) => a.path.compareTo(b.path))) {
    final before = _diffLines(change.before);
    final after = _diffLines(change.after);
    buffer
      ..writeln('--- ${change.path}')
      ..writeln('+++ ${change.path}')
      ..writeln(
        '@@ -${before.isEmpty ? 0 : 1},${before.length} '
        '+${after.isEmpty ? 0 : 1},${after.length} @@',
      );
    for (var index = 0; index < before.length; index++) {
      buffer.writeln('-${before[index]}');
      if (index == before.length - 1 && !change.before.endsWith('\n')) {
        buffer.writeln(r'\ No newline at end of file');
      }
    }
    for (var index = 0; index < after.length; index++) {
      buffer.writeln('+${after[index]}');
      if (index == after.length - 1 && !change.after.endsWith('\n')) {
        buffer.writeln(r'\ No newline at end of file');
      }
    }
  }
  return buffer.toString();
}

List<String> _diffLines(String contents) {
  if (contents.isEmpty) return const [];
  final lines = contents.split('\n');
  if (contents.endsWith('\n')) lines.removeLast();
  return [
    for (final line in lines)
      if (line.endsWith('\r')) line.substring(0, line.length - 1) else line,
  ];
}
