// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/prefer_arrow_body_on_same_line/prefer_arrow_body_on_same_line.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferArrowBodyOnSameLineTest);
  });
}

@reflectiveTest
class PreferArrowBodyOnSameLineTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferArrowBodyOnSameLine();
    super.setUp();
  }

  Future<void> test_reports_declarations_and_callbacks() async {
    const source = r'''
class Item {}
final items = <Item>[];
String formatItem(Item item) => 'item';
String formatParts(String name, String code) => '$name $code';
bool advanceAndCheck() => true;
String createLabel() => 'label';

String format(Item item) =>
    formatItem(item);

final names = items.map((item) =>
    formatItem(item));

class ItemIterator implements Iterator<Item> {
  @override
  Item get current => Item();

  @override
  bool moveNext() =>
      advanceAndCheck();
}

class Box {
  String _value = '';

  String get label =>
      createLabel();

  set value(String value) =>
      _value = value;

  Item operator +(Item other) =>
      other;
}
''';

    await assertDiagnostics(source, [
      for (final match in RegExp('=>').allMatches(source))
        if (source.startsWith('=>\n', match.start)) lint(match.start, 2),
    ]);
  }

  Future<void> test_ignores_multiline_expression_starting_after_arrow() async {
    await assertNoDiagnostics('''
class Item {
  String get name => '';
  String get code => '';
}
final items = <Item>[];
String formatParts(String name, String code) => '';

String format(Item item) => formatParts(
  item.name,
  item.code,
);

final names = items.map((item) => formatParts(
  item.name,
  item.code,
));
''');
  }

  Future<void> test_ignores_signature_wrapping_before_arrow() async {
    await assertNoDiagnostics('''
class Item {}
String formatItem(Item item) => '';

String format(
  Item item,
) => formatItem(item);
''');
  }

  Future<void> test_reports_expression_starting_after_arrow_line() async {
    const source = '''
class Item {}
String formatItem(Item item) => '';

String format(Item item)
    =>
    formatItem(item);
''';
    await assertDiagnostics(source, [lint(source.lastIndexOf('=>'), 2)]);
  }

  Future<void>
  test_incompatible_with_prefer_expression_function_bodies() async {
    expect(
      PreferArrowBodyOnSameLine().incompatibleRules,
      contains('prefer_expression_function_bodies'),
    );
  }
}
