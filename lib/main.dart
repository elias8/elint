import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/avoid_async_values_in_fields_and_constructors/avoid_async_values_in_fields_and_constructors.dart';
import 'src/rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields.dart';
import 'src/rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields_assist.dart';
import 'src/rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields_fix.dart';
import 'src/rules/prefer_returning_values_from_async_functions/prefer_returning_values_from_async_functions.dart';
import 'src/rules/prefer_returning_values_from_async_functions/prefer_returning_values_from_async_functions_assist.dart';
import 'src/rules/prefer_returning_values_from_async_functions/prefer_returning_values_from_async_functions_fix.dart';
import 'src/rules/sort_member_order/sort_member_order.dart';
import 'src/rules/sort_member_order/sort_member_order_assist.dart';
import 'src/rules/sort_member_order/sort_member_order_fix.dart';

/// The plugin entry point loaded by the Dart analysis server.
final plugin = ElintPlugin();

/// Registers the custom diagnostics provided by `elint`.
class ElintPlugin extends Plugin {
  @override
  String get name => 'elint';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerLintRule(AvoidAsyncValuesInFieldsAndConstructors())
      ..registerLintRule(AvoidDuplicatePrimaryConstructorFields())
      ..registerFixForRule(
        AvoidDuplicatePrimaryConstructorFields.code,
        AvoidDuplicatePrimaryConstructorFieldsFix.new,
      )
      ..registerAssist(AvoidDuplicatePrimaryConstructorFieldsAssist.new)
      ..registerLintRule(SortMemberOrder())
      ..registerFixForRule(SortMemberOrder.code, SortMemberOrderFix.new)
      ..registerAssist(SortMemberOrderAssist.new);
    registry
      ..registerLintRule(PreferReturningValuesFromAsyncFunctions())
      ..registerFixForRule(
        PreferReturningValuesFromAsyncFunctions.code,
        PreferReturningValuesFromAsyncFunctionsFix.new,
      )
      ..registerAssist(PreferReturningValuesFromAsyncFunctionsAssist.new);
  }
}
