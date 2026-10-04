import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Avoids primary-constructor fields copied to another field.
class AvoidDuplicatePrimaryConstructorFields() extends AnalysisRule {
  static const code = LintCode(
    'avoid_duplicate_primary_constructor_fields',
    'A primary-constructor field is duplicated by a field initializer.',
    correctionMessage:
        'Use the matching private field as the declaring parameter.',
  );

  this
    : super(
        name: 'avoid_duplicate_primary_constructor_fields',
        description:
            'Avoid primary-constructor fields copied to another field.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext _) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

class _Visitor(final AvoidDuplicatePrimaryConstructorFields rule)
    extends SimpleAstVisitor<void> {
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final primaryConstructor = node.namePart;
    if (primaryConstructor is! PrimaryConstructorDeclaration) return;

    final declaringParameters = <String, FormalParameter>{};
    for (final parameter in primaryConstructor.formalParameters.parameters) {
      final element = parameter.declaredFragment?.element;
      final name = parameter.name;
      if (name == null ||
          element is! FieldFormalParameterElement ||
          !element.isDeclaring) {
        continue;
      }
      declaringParameters[name.lexeme] = parameter;
    }
    if (declaringParameters.isEmpty) return;

    final reported = <FormalParameter>{};
    for (final member in node.body.members) {
      if (member is! FieldDeclaration || member.isStatic) continue;

      for (final field in member.fields.variables) {
        final initializer = field.initializer;
        if (initializer is! SimpleIdentifier) continue;

        final parameter = declaringParameters[initializer.name];
        if (parameter == null ||
            field.name.lexeme != '_${parameter.name?.lexeme}' ||
            initializer.element != parameter.declaredFragment?.element ||
            !reported.add(parameter)) {
          continue;
        }

        rule.reportAtNode(parameter);
      }
    }
  }
}
