import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Keeps post-frame scheduling for work that depends on a completed frame.
class AvoidPostFrameScheduling() extends AnalysisRule {
  static const code = LintCode(
    'avoid_post_frame_scheduling',
    'Post-frame work should be reserved for code that depends on a '
        'completed frame.',
    correctionMessage:
        'Use a lifecycle or event callback instead, or document why this work '
        'depends on a completed frame.',
  );

  this
    : super(
        name: 'avoid_post_frame_scheduling',
        description:
            'Avoid post-frame work unless it depends on a completed frame.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext _) {
    registry.addMethodInvocation(this, _Visitor(this));
    registry.addSimpleIdentifier(this, _Visitor(this));
  }
}

class _Visitor(final AvoidPostFrameScheduling rule)
    extends RecursiveAstVisitor<void> {
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final element = node.methodName.element;
    if (element is MethodElement &&
        element.name == 'addPostFrameCallback' &&
        _isFlutterSchedulerMember(element)) {
      rule.reportAtNode(node.methodName);
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    if (element is GetterElement &&
        element.name == 'endOfFrame' &&
        _isFlutterSchedulerMember(element)) {
      rule.reportAtNode(node);
    }

    super.visitSimpleIdentifier(node);
  }

  bool _isFlutterSchedulerMember(ExecutableElement element) {
    final owner = element.enclosingElement;
    return owner is ClassElement &&
        (owner.name == 'SchedulerBinding' || owner.name == 'WidgetsBinding') &&
        owner.library.uri.scheme == 'package' &&
        owner.library.uri.pathSegments.firstOrNull == 'flutter';
  }
}
