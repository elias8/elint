import 'dart:convert';
import 'dart:io';

import 'package:elint/tools.dart';
import 'package:test/test.dart';

void main() {
  group('runFixes sort_member_order', () {
    late Directory project;

    setUp(() {
      project = Directory.systemTemp.createTempSync('elint-member-order-');
      Directory('${project.path}/.dart_tool').createSync();
      Directory('${project.path}/lib').createSync();
      File('${project.path}/.dart_tool/package_config.json').writeAsStringSync(
        jsonEncode({'configVersion': 2, 'packages': <Object>[]}),
      );
      File('${project.path}/lib/example.dart').writeAsStringSync(_source);
    });

    tearDown(() => project.delete(recursive: true));

    void writeOptions({
      required bool enabled,
      String? order = '[constructors, fields, methods]',
    }) {
      final pluginPath = Directory.current.path.replaceAll(r'\', '/');
      final orderOption = order == null ? '' : '      order: $order\n';
      File('${project.path}/analysis_options.yaml').writeAsStringSync('''
plugins:
  elint:
    path: "$pluginPath"
    diagnostics:
      sort_member_order: $enabled
elint:
  diagnostics:
    sort_member_order:
$orderOption
''');
    }

    test('native enable dry run and apply converge idempotently', () async {
      writeOptions(enabled: true, order: null);
      final dryRun = await runFixes(
        FixRequest(mode: FixMode.dryRun),
        workingDirectory: project.path,
      );
      expect(dryRun.converged, isTrue);
      expect(dryRun.changes.single.after, _orderedSource);
      expect(
        File('${project.path}/lib/example.dart').readAsStringSync(),
        _source,
      );

      final applied = await runFixes(
        FixRequest(mode: FixMode.apply),
        workingDirectory: project.path,
      );
      expect(applied.changes.single.after, _orderedSource);
      expect(
        File('${project.path}/lib/example.dart').readAsStringSync(),
        _orderedSource,
      );

      final secondRun = await runFixes(
        FixRequest(mode: FixMode.apply),
        workingDirectory: project.path,
      );
      expect(secondRun.converged, isTrue);
      expect(secondRun.changes, isEmpty);
    });

    test(
      'disabled default selection does nothing, explicit selector keeps order',
      () async {
        writeOptions(enabled: false);
        final disabled = await runFixes(
          FixRequest(mode: FixMode.dryRun),
          workingDirectory: project.path,
        );
        expect(disabled.changes, isEmpty);

        final forced = await runFixes(
          FixRequest(mode: FixMode.dryRun, codes: ['sort_member_order']),
          workingDirectory: project.path,
        );
        expect(forced.changes.single.after, _customOrderedSource);
      },
    );

    test(
      'invalid selected configuration fails before any file write',
      () async {
        writeOptions(enabled: false, order: '[not_a_category]');
        await expectLater(
          runFixes(
            FixRequest(mode: FixMode.apply, codes: ['sort_member_order']),
            workingDirectory: project.path,
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              allOf(
                contains('analysis_options.yaml'),
                contains('unknown category'),
              ),
            ),
          ),
        );
        expect(
          File('${project.path}/lib/example.dart').readAsStringSync(),
          _source,
        );
      },
    );
  });
}

const _source = '''
class Example {
  Example();
  void run() {}
  int value = 0;
}
''';

const _orderedSource = '''
class Example {
  int value = 0;
  void run() {}
  Example();
}
''';

const _customOrderedSource = '''
class Example {
  Example();
  int value = 0;
  void run() {}
}
''';
