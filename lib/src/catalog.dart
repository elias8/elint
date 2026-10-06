import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/analysis/results.dart';

import 'rules/avoid_async_values_in_fields_and_constructors/avoid_async_values_in_fields_and_constructors.dart';
import 'rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields.dart';
import 'rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields_assist.dart';
import 'rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields_fix.dart';
import 'rules/prefer_arrow_body_on_same_line/prefer_arrow_body_on_same_line.dart';
import 'rules/prefer_arrow_body_on_same_line/prefer_arrow_body_on_same_line_assist.dart';
import 'rules/prefer_arrow_body_on_same_line/prefer_arrow_body_on_same_line_fix.dart';
import 'rules/prefer_returning_values_from_async_functions/prefer_returning_values_from_async_functions.dart';
import 'rules/prefer_returning_values_from_async_functions/prefer_returning_values_from_async_functions_assist.dart';
import 'rules/prefer_returning_values_from_async_functions/prefer_returning_values_from_async_functions_fix.dart';
import 'rules/sort_member_order/sort_member_order.dart';
import 'rules/sort_member_order/sort_member_order_assist.dart';
import 'rules/sort_member_order/sort_member_order_fix.dart';

typedef ElintProducerFactory = CorrectionProducer<ParsedUnitResult> Function({
  required CorrectionProducerContext context,
});
typedef ElintRuleFactory = AbstractAnalysisRule Function();

abstract final class ElintCatalog() {
  static final rules = <ElintRuleSpec>[
    ElintRuleSpec(
      code: PreferArrowBodyOnSameLine.code.lowerCaseName,
      groups: {'layout'},
      rule: PreferArrowBodyOnSameLine.new,
      fix: PreferArrowBodyOnSameLineFix.new,
      assist: PreferArrowBodyOnSameLineAssist.new,
    ),
    ElintRuleSpec(
      code: AvoidAsyncValuesInFieldsAndConstructors.code.lowerCaseName,
      groups: {'async'},
      rule: AvoidAsyncValuesInFieldsAndConstructors.new,
    ),
    ElintRuleSpec(
      code: AvoidDuplicatePrimaryConstructorFields.code.lowerCaseName,
      groups: const {},
      rule: AvoidDuplicatePrimaryConstructorFields.new,
      fix: AvoidDuplicatePrimaryConstructorFieldsFix.new,
      assist: AvoidDuplicatePrimaryConstructorFieldsAssist.new,
    ),
    ElintRuleSpec(
      code: SortMemberOrder.code.lowerCaseName,
      groups: {'layout'},
      rule: SortMemberOrder.new,
      fix: SortMemberOrderFix.new,
      assist: SortMemberOrderAssist.new,
    ),
    ElintRuleSpec(
      code: PreferReturningValuesFromAsyncFunctions.code.lowerCaseName,
      groups: {'async'},
      rule: PreferReturningValuesFromAsyncFunctions.new,
      fix: PreferReturningValuesFromAsyncFunctionsFix.new,
      assist: PreferReturningValuesFromAsyncFunctionsAssist.new,
    ),
  ];

  static final byCode = {
    for (final rule in rules) normalizeCode(rule.code): rule,
  };

  static final groups = <String, Set<String>>{
    for (final group in rules.expand((rule) => rule.groups).toSet())
      group: {
        for (final rule in rules)
          if (rule.groups.contains(group)) normalizeCode(rule.code),
      },
  };

  static String normalizeCode(String value) {
    final code = value.trim().toLowerCase();
    return code.startsWith('elint/') ? code.substring('elint/'.length) : code;
  }
}

final class const ElintRuleSpec({
  required final String code,
  required final Set<String> groups,
  required final ElintRuleFactory rule,
  final ElintProducerFactory? fix,
  final ElintProducerFactory? assist,
});
