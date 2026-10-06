import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Keeps the start of an arrow body on the same line as `=>`.
class PreferArrowBodyOnSameLine() extends AnalysisRule {
  static const code = LintCode(
    'prefer_arrow_body_on_same_line',
    'The expression should start on the same line as `=>`.',
    correctionMessage: 'Use a block body when the expression starts later.',
  );

  this
    : super(
        name: 'prefer_arrow_body_on_same_line',
        description:
            'Keep the start of an arrow body on the same line as `=>`.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  List<String> get incompatibleRules => const [
    'prefer_expression_function_bodies',
  ];

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext _) {
    registry.addExpressionFunctionBody(this, _Visitor(this));
  }
}

class _Visitor(final PreferArrowBodyOnSameLine rule)
    extends SimpleAstVisitor<void> {
  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    final unit = node.thisOrAncestorOfType<CompilationUnit>();
    if (unit == null) return;

    final arrowLine = unit.lineInfo
        .getLocation(node.functionDefinition.offset)
        .lineNumber;
    final expressionLine = unit.lineInfo
        .getLocation(node.expression.offset)
        .lineNumber;
    if (arrowLine != expressionLine) {
      rule.reportAtOffset(
        node.functionDefinition.offset,
        node.functionDefinition.length,
      );
    }
  }
}
