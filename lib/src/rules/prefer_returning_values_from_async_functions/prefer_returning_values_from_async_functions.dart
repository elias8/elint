import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'future_value_return_call.dart';

/// Prefers returning values directly from asynchronous functions.
class PreferReturningValuesFromAsyncFunctions() extends AnalysisRule {
  static const code = LintCode(
    'prefer_returning_values_from_async_functions',
    'Avoid returning `Future.value` from a function.',
    correctionMessage:
        'Return the value directly; mark the function `async` if needed.',
  );

  this
    : super(
        name: 'prefer_returning_values_from_async_functions',
        description:
            'Prefer returning values directly from asynchronous functions.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext _) {
    registry.addReturnStatement(this, _Visitor(this));
    registry.addExpressionFunctionBody(this, _Visitor(this));
  }
}

class _Visitor(final PreferReturningValuesFromAsyncFunctions rule)
    extends SimpleAstVisitor<void> {
  @override
  void visitReturnStatement(ReturnStatement node) {
    final expression = node.expression;
    final body = _functionBodyFor(node);
    if (expression == null ||
        futureValueReturnCall(expression) == null ||
        body == null ||
        body.isGenerator ||
        !functionSupportsAsyncReturn(body)) {
      return;
    }

    rule.reportAtNode(expression);
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    final expression = node.expression;
    if (futureValueReturnCall(expression) == null ||
        node.isGenerator ||
        !functionSupportsAsyncReturn(node)) {
      return;
    }

    rule.reportAtNode(expression);
  }
}

FunctionBody? _functionBodyFor(AstNode node) {
  var parent = node.parent;
  while (parent != null) {
    if (parent is FunctionBody) return parent;
    parent = parent.parent;
  }
  return null;
}
