import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

Future<void> addArrowBodyBlockEdit(
  AstNode node,
  String content,
  String file,
  ChangeBuilder builder, {
  required TypeProvider typeProvider,
  required TypeSystem typeSystem,
  int? selectionOffset,
  int selectionLength = 0,
}) async {
  final body = _expressionFunctionBody(node);
  if (body == null ||
      body.semicolon == null && body.parent is! FunctionExpression) {
    return;
  }

  final unit = body.thisOrAncestorOfType<CompilationUnit>();
  if (unit == null ||
      unit.lineInfo.getLocation(body.functionDefinition.offset).lineNumber ==
          unit.lineInfo.getLocation(body.expression.offset).lineNumber) {
    return;
  }

  final expression = body.expression;
  final functionReturnType = _returnType(body);
  final expressionType = expression.staticType;
  if (functionReturnType == null ||
      expressionType == null ||
      functionReturnType is DynamicType ||
      functionReturnType is InvalidType ||
      expressionType is DynamicType ||
      expressionType is InvalidType) {
    return;
  }

  if (selectionOffset != null) {
    final selectionEnd = selectionOffset + selectionLength;
    final bodyEnd = body.semicolon?.end ?? expression.end;
    if (selectionOffset < body.functionDefinition.offset ||
        selectionEnd > bodyEnd ||
        (selectionLength == 0 && selectionOffset > bodyEnd)) {
      return;
    }
  }

  if (body.semicolon == null &&
      _containsComment(
        content,
        expression.end,
        expression.endToken.next?.offset ?? expression.end,
      )) {
    return;
  }

  const arrowReplacement = '{';
  final action = _blockAction(
    functionReturnType,
    expressionType,
    body,
    typeProvider,
    typeSystem,
  );
  if (action == null) return;
  final returnInsertion = action == _BlockAction.returnExpression
      ? 'return '
      : null;
  final closingInsertionOffset = body.semicolon?.end ?? expression.end;
  final closingInsertion = body.semicolon == null ? ';}' : '}';

  await builder.addDartFileEdit(file, (fileBuilder) {
    fileBuilder.addSimpleReplacement(
      SourceRange(
        body.functionDefinition.offset,
        body.functionDefinition.length,
      ),
      arrowReplacement,
    );
    if (returnInsertion != null) {
      fileBuilder.addSimpleInsertion(expression.offset, returnInsertion);
    }
    if (action == _BlockAction.awaitExpression) {
      fileBuilder.addSimpleInsertion(expression.offset, 'await (');
      fileBuilder.addSimpleInsertion(expression.end, ')');
    }
    fileBuilder.addSimpleInsertion(closingInsertionOffset, closingInsertion);
  });
}

ExpressionFunctionBody? _expressionFunctionBody(AstNode node) {
  AstNode? current = node;
  while (current != null) {
    if (current is ExpressionFunctionBody) return current;
    current = current.parent;
  }
  return null;
}

DartType? _returnType(ExpressionFunctionBody body) {
  final parent = body.parent;
  if (parent is FragmentDeclaringNode) {
    final fragment = parent.declaredFragment;
    if (fragment is ExecutableFragment) return fragment.element.returnType;
  }
  if (parent is FunctionExpression) {
    final staticType = parent.staticType;
    if (staticType is FunctionType) return staticType.returnType;
  }
  return null;
}

enum _BlockAction() {
  expressionStatement,
  returnExpression,
  awaitExpression,
}

_BlockAction? _blockAction(
  DartType functionReturnType,
  DartType expressionType,
  ExpressionFunctionBody body,
  TypeProvider typeProvider,
  TypeSystem typeSystem,
) {
  if (functionReturnType is VoidType || expressionType is NeverType) {
    return _BlockAction.expressionStatement;
  }

  if (!body.isAsynchronous) return _BlockAction.returnExpression;

  if (!_isVoidFuture(functionReturnType)) {
    return _BlockAction.returnExpression;
  }
  if (expressionType is VoidType) return _BlockAction.expressionStatement;
  if (_isFutureOrFutureOr(expressionType, typeProvider, typeSystem)) {
    return _BlockAction.awaitExpression;
  }
  if (expressionType is DynamicType || expressionType is InvalidType) {
    return null;
  }
  return _BlockAction.expressionStatement;
}

bool _isVoidFuture(DartType type) {
  if (type is! InterfaceType || type.typeArguments.length != 1) return false;
  return (type.isDartAsyncFuture || type.isDartAsyncFutureOr) &&
      type.typeArguments.single is VoidType;
}

bool _isFutureOrFutureOr(
  DartType type,
  TypeProvider typeProvider,
  TypeSystem typeSystem,
) {
  if (type is DynamicType || type is InvalidType) return false;
  final futureType = typeProvider.futureType(typeProvider.dynamicType);
  if (typeSystem.isSubtypeOf(type, futureType)) return true;
  final futureOrType = typeProvider.futureOrType(typeProvider.dynamicType);
  return typeSystem.isSubtypeOf(type, futureOrType);
}

bool _containsComment(String content, int start, int end) {
  if (start >= end) return false;
  final trivia = content.substring(start, end);
  return trivia.contains('//') || trivia.contains('/*');
}
