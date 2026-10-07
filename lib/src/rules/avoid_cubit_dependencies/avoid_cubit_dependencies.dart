import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Avoids direct dependencies between Cubit implementations.
class AvoidCubitDependencies() extends AnalysisRule {
  static const code = LintCode(
    'avoid_cubit_dependencies',
    'A Cubit implementation shouldn’t depend on another Cubit.',
    correctionMessage:
        'Coordinate through the presentation layer or a shared domain source.',
  );

  this
    : super(
        name: 'avoid_cubit_dependencies',
        description:
            'Avoid direct dependencies between Cubit implementations. '
            'Coordinate through the presentation layer or a shared domain '
            'source.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext _) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

class _Visitor(final AvoidCubitDependencies rule)
    extends RecursiveAstVisitor<void> {
  var _cubitDepth = 0;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    final isCubit = element != null && _isCubitImplementation(element);
    if (isCubit) _cubitDepth++;
    super.visitClassDeclaration(node);
    if (isCubit) _cubitDepth--;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final element = node.methodName.element;
    final cubit = element is ConstructorElement
        ? element.enclosingElement
        : null;
    if (_cubitDepth > 0 &&
        cubit is ClassElement &&
        _isCubitImplementation(cubit)) {
      rule.reportAtNode(node.methodName);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedType(NamedType node) {
    final element = node.element;
    if (_cubitDepth > 0 &&
        element is ClassElement &&
        _isCubitImplementation(element)) {
      rule.reportAtToken(node.name);
    }
    super.visitNamedType(node);
  }

  bool _isBlocCubitClass(ClassElement element) {
    return element.name == 'Cubit' &&
        element.library.uri.scheme == 'package' &&
        element.library.uri.pathSegments.firstOrNull == 'bloc';
  }

  bool _isCubitImplementation(ClassElement element) {
    final visited = <ClassElement>{element};
    final superclass = element.supertype?.element;
    ClassElement? current = superclass is ClassElement ? superclass : null;

    while (current != null && visited.add(current)) {
      if (_isBlocCubitClass(current)) return true;
      final superclass = current.supertype?.element;
      current = superclass is ClassElement ? superclass : null;
    }

    return false;
  }
}
