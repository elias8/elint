import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// Keeps public Cubit method results in state.
class AvoidReturningValuesFromCubits() extends AnalysisRule {
  static const code = LintCode(
    'avoid_returning_values_from_cubits',
    'Public Cubit methods should not return values.',
    correctionMessage:
        'Return void or Future<void> and expose results through Cubit state.',
  );

  this
    : super(
        name: 'avoid_returning_values_from_cubits',
        description:
            'Do keep public Cubit method results in state; return void or '
            'Future<void>.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext _) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

class _Visitor(final AvoidReturningValuesFromCubits rule)
    extends RecursiveAstVisitor<void> {
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element != null && _isCubitImplementation(element)) {
      for (final member in node.body.members) {
        if (member case final MethodDeclaration method
            when !method.isStatic &&
                !method.isGetter &&
                !method.isSetter &&
                !method.isOperator &&
                !method.name.lexeme.startsWith('_') &&
                !_returnsVoid(method)) {
          if (method.returnType case final returnType?) {
            rule.reportAtNode(returnType);
          } else {
            rule.reportAtToken(method.name);
          }
        }
      }
    }

    super.visitClassDeclaration(node);
  }

  bool _returnsVoid(MethodDeclaration method) {
    final returnType = method.declaredFragment?.element.returnType;
    if (returnType is VoidType) return true;
    return returnType is InterfaceType &&
        returnType.isDartAsyncFuture &&
        returnType.nullabilitySuffix == NullabilitySuffix.none &&
        returnType.typeArguments.length == 1 &&
        returnType.typeArguments.single is VoidType;
  }

  bool _isCubitImplementation(ClassElement element) {
    final visited = <ClassElement>{element};
    final superclass = element.supertype?.element;
    ClassElement? current = superclass is ClassElement ? superclass : null;

    while (current != null && visited.add(current)) {
      if (current.name == 'Cubit' &&
          current.library.uri.scheme == 'package' &&
          current.library.uri.pathSegments.firstOrNull == 'bloc') {
        return true;
      }
      final superclass = current.supertype?.element;
      current = superclass is ClassElement ? superclass : null;
    }

    return false;
  }
}
