import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/analysis/results.dart';

import 'rules/avoid_async_values_in_fields_and_constructors/avoid_async_values_in_fields_and_constructors.dart';
import 'rules/avoid_cubit_dependencies/avoid_cubit_dependencies.dart';
import 'rules/avoid_cubit_parameters_in_widget_constructors/avoid_cubit_parameters_in_widget_constructors.dart';
import 'rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields.dart';
import 'rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields_assist.dart';
import 'rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields_fix.dart';
import 'rules/avoid_flutter_imports_in_cubits/avoid_flutter_imports_in_cubits.dart';
import 'rules/avoid_post_frame_scheduling/avoid_post_frame_scheduling.dart';
import 'rules/avoid_returning_values_from_cubits/avoid_returning_values_from_cubits.dart';
import 'rules/prefer_arrow_body_on_same_line/prefer_arrow_body_on_same_line.dart';
import 'rules/prefer_arrow_body_on_same_line/prefer_arrow_body_on_same_line_assist.dart';
import 'rules/prefer_arrow_body_on_same_line/prefer_arrow_body_on_same_line_fix.dart';
import 'rules/prefer_async_await/prefer_async_await.dart';
import 'rules/prefer_async_await/prefer_async_await_assist.dart';
import 'rules/prefer_async_await/prefer_async_await_fix.dart';
import 'rules/prefer_matching_cubit_file_names/prefer_matching_cubit_file_names.dart';
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
      code: AvoidCubitParametersInWidgetConstructors.code.lowerCaseName,
      groups: {'architecture'},
      rule: AvoidCubitParametersInWidgetConstructors.new,
    ),
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
      code: AvoidCubitDependencies.code.lowerCaseName,
      groups: {'architecture'},
      rule: AvoidCubitDependencies.new,
    ),
    ElintRuleSpec(
      code: AvoidFlutterImportsInCubits.code.lowerCaseName,
      groups: {'architecture'},
      rule: AvoidFlutterImportsInCubits.new,
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
      code: PreferAsyncAwait.code.lowerCaseName,
      groups: {'async'},
      rule: PreferAsyncAwait.new,
      fix: PreferAsyncAwaitFix.new,
      assist: PreferAsyncAwaitAssist.new,
    ),
    ElintRuleSpec(
      code: PreferReturningValuesFromAsyncFunctions.code.lowerCaseName,
      groups: {'async'},
      rule: PreferReturningValuesFromAsyncFunctions.new,
      fix: PreferReturningValuesFromAsyncFunctionsFix.new,
      assist: PreferReturningValuesFromAsyncFunctionsAssist.new,
    ),
    ElintRuleSpec(
      code: AvoidReturningValuesFromCubits.code.lowerCaseName,
      groups: {'architecture'},
      rule: AvoidReturningValuesFromCubits.new,
    ),
    ElintRuleSpec(
      code: AvoidPostFrameScheduling.code.lowerCaseName,
      groups: {'layout'},
      rule: AvoidPostFrameScheduling.new,
    ),
    ElintRuleSpec(
      code: PreferMatchingCubitFileNames.code.lowerCaseName,
      groups: {'architecture'},
      rule: PreferMatchingCubitFileNames.new,
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
