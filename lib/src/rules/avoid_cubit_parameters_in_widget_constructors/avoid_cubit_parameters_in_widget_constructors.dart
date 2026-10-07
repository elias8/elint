import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// Encourages widgets to access Cubits from the widget tree.
class AvoidCubitParametersInWidgetConstructors() extends AnalysisRule {
  static const code = LintCode(
    'avoid_cubit_parameters_in_widget_constructors',
    'Widget constructors should not accept Cubits.',
    correctionMessage:
        'Provide the Cubit above this widget and access it from the widget '
        'tree.',
  );

  this
    : super(
        name: 'avoid_cubit_parameters_in_widget_constructors',
        description: 'Do access Cubits through the widget tree.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext _) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

class _Visitor(final AvoidCubitParametersInWidgetConstructors rule)
    extends RecursiveAstVisitor<void> {
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element is ClassElement && _isFlutterWidget(element)) {
      final namePart = node.namePart;
      if (namePart is PrimaryConstructorDeclaration) {
        _reportCubits(namePart.formalParameters);
      }

      for (final member in node.body.members) {
        if (member is ConstructorDeclaration) {
          _reportCubits(member.parameters);
        }
      }
    }

    super.visitClassDeclaration(node);
  }

  void _reportCubits(FormalParameterList parameters) {
    for (final parameter in parameters.parameters) {
      final element = parameter.declaredFragment?.element;
      final type = element is FormalParameterElement
          ? element.type
          : parameter.type?.type;
      if (!_isCubitType(type)) continue;

      final name = parameter.name;
      if (name == null) {
        rule.reportAtNode(parameter);
      } else {
        rule.reportAtToken(name);
      }
    }
  }

  bool _isCubitType(DartType? type) {
    if (type == null) return false;

    final element = type.element;
    if (element is ClassElement && _isCubitClass(element)) return true;

    final aliasedElement = type.alias?.element.aliasedType.element;
    return aliasedElement is ClassElement && _isCubitClass(aliasedElement);
  }

  bool _isCubitClass(ClassElement element) {
    if (_isBlocCubit(element)) return true;
    return element.allSupertypes.any((type) {
      final supertype = type.element;
      return supertype is ClassElement && _isBlocCubit(supertype);
    });
  }

  bool _isFlutterWidget(ClassElement element) {
    return element.allSupertypes.any((type) {
      final supertype = type.element;
      return supertype is ClassElement &&
          supertype.name == 'Widget' &&
          supertype.library.uri.scheme == 'package' &&
          supertype.library.uri.pathSegments.firstOrNull == 'flutter';
    });
  }

  bool _isBlocCubit(ClassElement element) {
    return element.name == 'Cubit' &&
        element.library.uri.scheme == 'package' &&
        element.library.uri.pathSegments.firstOrNull == 'bloc';
  }
}
