import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
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
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry
      ..addClassDeclaration(this, visitor)
      ..addConstructorDeclaration(this, visitor)
      ..addEnumDeclaration(this, visitor)
      ..addExtensionTypeDeclaration(this, visitor)
      ..addFieldDeclaration(this, visitor);
  }
}

class _Visitor(
  final AvoidAsyncValuesInFieldsAndConstructors rule,
  RuleContext context,
) extends SimpleAstVisitor<void> {
  final _references = _OperationReferences();

  this {
    for (final unit in context.allUnits) {
      unit.unit.accept(_references);
    }
  }

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
      if (type != null &&
          _isFutureLike(type) &&
          !_isTransientOwnedOperation(variable)) {
        rule.reportAtToken(variable.name);
      }
    }
  }

  bool _isTransientOwnedOperation(VariableDeclaration variable) {
    final field = variable.declaredFragment?.element;
    final declaration = variable.thisOrAncestorOfType<ClassDeclaration>();
    if (field is! FieldElement ||
        declaration == null ||
        !field.isPrivate ||
        field.isStatic ||
        field.isFinal ||
        field.isLate ||
        !field.type.isDartAsyncFuture ||
        field.type.nullabilitySuffix != NullabilitySuffix.question ||
        variable.initializer != null ||
        _references.constructorFields.contains(field)) {
      return false;
    }
    final element = declaration.declaredFragment?.element;
    if (element == null ||
        element.fields.where((candidate) {
              return !candidate.isOriginGetterSetter &&
                  _isFutureLike(candidate.type);
            }).length !=
            1) {
      return false;
    }
    final writes = _references.assignments[field];
    if (writes == null ||
        writes.length != 2 ||
        _references.otherWrites.contains(field)) {
      return false;
    }
    final starts = writes.where((write) => write.rightHandSide is! NullLiteral);
    final resets = writes.where((write) => write.rightHandSide is NullLiteral);
    if (starts.length != 1 || resets.length != 1) return false;
    final start = starts.single;
    final reset = resets.single;
    if (!_isThisAssignment(start) || !_isThisAssignment(reset)) return false;
    final invocation = start.rightHandSide;
    if (invocation is! MethodInvocation) return false;
    final receiver = invocation.target?.unParenthesized;
    if (receiver != null && receiver is! ThisExpression) return false;
    final operation = invocation.methodName.element;
    if (operation is! MethodElement ||
        !operation.isPrivate ||
        operation.isStatic ||
        operation.enclosingElement != element) {
      return false;
    }
    if (_references.startsDuringConstruction(operation)) return false;
    final owner = reset.thisOrAncestorOfType<MethodDeclaration>();
    final starter = start.thisOrAncestorOfType<MethodDeclaration>();
    if (owner == null ||
        starter == null ||
        owner.declaredFragment?.element != operation ||
        starter.declaredFragment?.element.enclosingElement != element ||
        (starter.declaredFragment?.element.isStatic ?? true)) {
      return false;
    }
    final body = owner.body;
    if (body is! BlockFunctionBody ||
        !body.isAsynchronous ||
        body.isGenerator ||
        body.block.statements.length != 1) {
      return false;
    }
    final outer = body.block.statements.single;
    if (outer is! TryStatement) return false;
    final statements = outer.finallyBlock?.statements;
    return statements != null &&
        statements.length == 1 &&
        statements.single is ExpressionStatement &&
        (statements.single as ExpressionStatement).expression == reset &&
        !_isNestedClosure(start, starter);
  }

  bool _isThisAssignment(AssignmentExpression assignment) {
    if (assignment.operator.lexeme != '=') return false;
    final target = assignment.leftHandSide;
    return target is SimpleIdentifier ||
        (target is PropertyAccess && target.target is ThisExpression);
  }

  bool _isNestedClosure(AstNode node, MethodDeclaration method) {
    for (var parent = node.parent; parent != method; parent = parent.parent) {
      if (parent == null ||
          parent is FunctionExpression ||
          parent is FunctionDeclaration) {
        return true;
      }
    }
    return false;
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

class _OperationReferences() extends RecursiveAstVisitor<void> {
  final assignments = <FieldElement, List<AssignmentExpression>>{};
  final otherWrites = <FieldElement>{};
  final constructorFields = <FieldElement>{};

  final _constructorCalls = <InstanceElement, Set<MethodElement>>{};
  final _methodCalls = <MethodElement, Set<MethodElement>>{};

  bool startsDuringConstruction(MethodElement operation) {
    final pending = <MethodElement>[
      ...?_constructorCalls[operation.enclosingElement],
    ];
    final visited = <MethodElement>{};
    while (pending.isNotEmpty) {
      final method = pending.removeLast();
      if (!visited.add(method)) continue;
      if (method == operation) return true;
      pending.addAll(_methodCalls[method] ?? const <MethodElement>{});
    }
    return false;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final called = node.methodName.element;
    if (called is MethodElement &&
        !called.isStatic &&
        (node.target == null ||
            node.target?.unParenthesized is ThisExpression)) {
      _recordCall(node, called);
    }
    super.visitMethodInvocation(node);
  }

  void _recordCall(MethodInvocation invocation, MethodElement called) {
    final owner = called.enclosingElement;
    if (owner is! InstanceElement) return;
    for (var scope = invocation.parent; scope != null; scope = scope.parent) {
      if (scope is FunctionDeclaration) return;
      if (scope is FunctionExpression) {
        AstNode expression = scope;
        var parent = expression.parent;
        while (parent is ParenthesizedExpression) {
          expression = parent;
          parent = parent.parent;
        }
        if (parent is! FunctionExpressionInvocation ||
            parent.function != expression) {
          return;
        }
      }
      if (scope is MethodDeclaration) {
        final method = scope.declaredFragment?.element;
        if (method is MethodElement && method.enclosingElement == owner) {
          (_methodCalls[method] ??= {}).add(called);
        }
        return;
      }
      final ConstructorElement? constructor;
      if (scope is ConstructorDeclaration) {
        constructor = scope.declaredFragment?.element;
      } else if (scope is PrimaryConstructorBody) {
        constructor = scope.declaration?.declaredFragment?.element;
      } else {
        continue;
      }
      if (constructor != null && constructor.enclosingElement == owner) {
        (_constructorCalls[owner] ??= {}).add(called);
      }
      return;
    }
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final field = _field(node.writeElement);
    if (field != null) {
      (assignments[field] ??= []).add(node);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    final field = _field(node.writeElement);
    if (field != null) otherWrites.add(field);
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    final field = _field(node.writeElement);
    if (field != null) otherWrites.add(field);
    super.visitPostfixExpression(node);
  }

  @override
  void visitConstructorFieldInitializer(ConstructorFieldInitializer node) {
    final field = _field(node.fieldName.element);
    if (field != null) constructorFields.add(field);
    super.visitConstructorFieldInitializer(node);
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    final element = node.declaredFragment?.element;
    if (element is FieldFormalParameterElement && element.field != null) {
      constructorFields.add(element.field!);
    }
    super.visitFieldFormalParameter(node);
  }

  FieldElement? _field(Element? element) {
    if (element is FieldElement) return element;
    if (element is PropertyAccessorElement &&
        element.variable is FieldElement) {
      return element.variable as FieldElement;
    }
    return null;
  }
}
