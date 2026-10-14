// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/avoid_post_frame_scheduling/avoid_post_frame_scheduling.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidPostFrameSchedulingTest);
  });
}

@reflectiveTest
class AvoidPostFrameSchedulingTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidPostFrameScheduling();
    newPackage('flutter').addFile('lib/scheduler.dart', '''
abstract class SchedulerBinding() {
  static SchedulerBinding get instance => throw UnimplementedError();

  void addPostFrameCallback(void Function(Duration) callback);
  void scheduleFrameCallback(void Function(Duration) callback);
  Future<void> get endOfFrame;
}

abstract class WidgetsBinding() implements SchedulerBinding {
  static WidgetsBinding get instance => throw UnimplementedError();
}
''');
    super.setUp();
  }

  Future<void> test_reports_scheduler_and_widget_binding_callbacks() async {
    const source = '''
import 'package:flutter/scheduler.dart' as flutter;
import 'package:flutter/scheduler.dart';

void schedule() {
  WidgetsBinding.instance.addPostFrameCallback((_) {});
  SchedulerBinding.instance.addPostFrameCallback((_) {});
  flutter.WidgetsBinding.instance.addPostFrameCallback((_) {});
}
''';

    await assertDiagnostics(source, [
      lint(
        source.indexOf('addPostFrameCallback'),
        'addPostFrameCallback'.length,
      ),
      lint(
        source.indexOf(
          'addPostFrameCallback',
          source.indexOf('SchedulerBinding.instance'),
        ),
        'addPostFrameCallback'.length,
      ),
      lint(
        source.lastIndexOf('addPostFrameCallback'),
        'addPostFrameCallback'.length,
      ),
    ]);
  }

  Future<void> test_reports_end_of_frame_reads() async {
    const source = '''
import 'package:flutter/scheduler.dart';

Future<void> waitForFrame() async {
  await SchedulerBinding.instance.endOfFrame;
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('endOfFrame'), 'endOfFrame'.length),
    ]);
  }

  Future<void> test_ignores_other_scheduler_methods() async {
    const source = '''
import 'package:flutter/scheduler.dart';

void schedule() {
  SchedulerBinding.instance.scheduleFrameCallback((_) {});
}
''';

    await assertNoDiagnostics(source);
  }

  Future<void> test_ignores_unrelated_members_with_the_same_names() async {
    const source = '''
class SchedulerBinding {
  void addPostFrameCallback(void Function() callback) {}
  Future<void> get endOfFrame async {}
}

Future<void> schedule(SchedulerBinding binding) async {
  binding.addPostFrameCallback(() {});
  await binding.endOfFrame;
}
''';

    await assertNoDiagnostics(source);
  }
}
