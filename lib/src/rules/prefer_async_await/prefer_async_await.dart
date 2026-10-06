import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Prefers `async`/`await` over `Future.then()`.
class PreferAsyncAwait() extends AnalysisRule {
  static const code = LintCode(
    'prefer_async_await',
    'Avoid `Future.then()`.',
    correctionMessage: 'Use `async`/`await` instead.',
  );

  this
    : super(
        name: 'prefer_async_await',
        description: 'Prefer `async`/`await` over `Future.then()`.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext _) {
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

class _Visitor(final PreferAsyncAwait rule) extends SimpleAstVisitor<void> {
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final method = node.methodName.element;
    final owner = method?.enclosingElement;
    if (node.methodName.name == 'then' &&
        owner?.name == 'Future' &&
        (owner?.library?.isDartAsync ?? false)) {
      rule.reportAtNode(node.methodName);
    }
  }
}
