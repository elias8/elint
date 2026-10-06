import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

typedef FutureValueReturnCall = ({
  Expression expression,
  ArgumentList arguments,
});

FutureValueReturnCall? futureValueReturnCall(Expression expression) {
  switch (expression) {
    case InstanceCreationExpression(
      :final constructorName,
      :final argumentList,
    ):
      return _callFor(constructorName.element, argumentList, expression);
    case MethodInvocation(:final methodName, :final argumentList):
      final constructor = methodName.element;
      if (constructor is ConstructorElement) {
        return _callFor(constructor, argumentList, expression);
      }
      return null;
    default:
      return null;
  }
}

bool functionSupportsAsyncReturn(FunctionBody body) {
  final parent = body.parent;
  final returnType = switch (parent) {
    MethodDeclaration(:final declaredFragment) =>
      declaredFragment?.element.returnType,
    FunctionExpression(:final declaredFragment, :final staticType) =>
      declaredFragment?.element.returnType ??
          (staticType is FunctionType ? staticType.returnType : null),
    _ => null,
  };
  return returnType != null &&
      (returnType.isDartAsyncFuture ||
          returnType.isDartAsyncFutureOr ||
          returnType is DynamicType);
}

FutureValueReturnCall? _callFor(
  ConstructorElement? constructor,
  ArgumentList arguments,
  Expression expression,
) {
  if (constructor == null ||
      constructor.name != 'value' ||
      constructor.enclosingElement.name != 'Future' ||
      constructor.library.uri != Uri.parse('dart:async') ||
      arguments.arguments.length != 1) {
    return null;
  }
  return (expression: expression, arguments: arguments);
}
