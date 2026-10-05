import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// Keeps pending asynchronous work out of class state and constructor inputs.
class AvoidAsyncValuesInFieldsAndConstructors() extends AnalysisRule {
  static const code = LintCode(
    'avoid_async_values_in_fields_and_constructors',
    'Keep asynchronous work out of class state and constructor inputs.',
    correctionMessage:
        'Pass resolved data or a service to the constructor, then start work '
        'from a method.',
  );

  this
    : super(
        name: 'avoid_async_values_in_fields_and_constructors',
        description:
            'Keep pending asynchronous work out of class state and '
            'constructor inputs.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext _) {
    final visitor = _Visitor(this);
    registry
      ..addClassDeclaration(this, visitor)
      ..addConstructorDeclaration(this, visitor)
      ..addEnumDeclaration(this, visitor)
      ..addExtensionTypeDeclaration(this, visitor)
      ..addFieldDeclaration(this, visitor);
  }
}

class _Visitor(final AvoidAsyncValuesInFieldsAndConstructors rule)
    extends SimpleAstVisitor<void> {
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _reportPrimaryConstructorParameters(node.namePart);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _reportConstructorParameters(node.parameters);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _reportPrimaryConstructorParameters(node.namePart);
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    _reportPrimaryConstructorParameters(node.namePart);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    for (final variable in node.fields.variables) {
      final type = variable.declaredFragment?.element.type;
      if (type != null && _isFutureLike(type)) {
        rule.reportAtToken(variable.name);
      }
    }
  }

  bool _isFutureLike(DartType type) {
    if (type.isDartAsyncFuture || type.isDartAsyncFutureOr) return true;

    final element = type.element;
    return element is ClassElement &&
        element.name == 'Completer' &&
        element.library.isDartAsync;
  }

  void _reportConstructorParameters(FormalParameterList parameters) {
    for (final parameter in parameters.parameters) {
      _reportIfAsyncConstructorInput(parameter);
    }
  }

  void _reportIfAsyncConstructorInput(FormalParameter parameter) {
    final type = parameter.declaredFragment?.element.type;
    if (type == null) return;

    if (_isFutureLike(type) ||
        (type is FunctionType && _isFutureLike(type.returnType))) {
      rule.reportAtNode(parameter);
    }
  }

  void _reportPrimaryConstructorParameters(ClassNamePart namePart) {
    if (namePart is! PrimaryConstructorDeclaration) return;

    _reportConstructorParameters(namePart.formalParameters);
  }
}
