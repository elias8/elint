import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

import 'future_value_return_call.dart';

Future<void> addFutureValueReturnEdit(
  AstNode node,
  String content,
  String file,
  ChangeBuilder builder, {
  int? selectionOffset,
  int selectionLength = 0,
  bool applyToFunction = false,
}) async {
  final expression = _futureValueExpression(node);
  final body = expression == null ? null : _functionBodyFor(expression);
  if (expression == null ||
      body == null ||
      !functionSupportsAsyncReturn(body)) {
    return;
  }

  if (selectionOffset != null) {
    final selectionEnd = selectionOffset + selectionLength;
    if (selectionOffset > expression.end ||
        selectionEnd < expression.offset ||
        (selectionLength == 0 &&
            (selectionOffset < expression.offset ||
                selectionOffset > expression.end))) {
      return;
    }
  }

  final calls = applyToFunction
      ? _returnedFutureValues(body)
      : [futureValueReturnCall(expression)!];
  if (calls.isEmpty || calls.any((call) => !_canEdit(call, content))) return;

  final existingEdits = [
    for (final fileEdit in builder.sourceChange.edits)
      if (fileEdit.file == file) ...fileEdit.edits,
  ];
  final callsToEdit = applyToFunction
      ? calls
            .where(
              (call) => !existingEdits.any(
                (edit) =>
                    edit.offset == call.expression.offset &&
                    edit.length == call.expression.length,
              ),
            )
            .toList()
      : calls;
  final needsAsync =
      !body.isAsynchronous &&
      !existingEdits.any(
        (edit) =>
            edit.offset == body.offset &&
            edit.length == 0 &&
            edit.replacement == 'async ',
      );
  if (callsToEdit.isEmpty && !needsAsync) return;

  await builder.addDartFileEdit(file, (fileBuilder) {
    if (needsAsync) {
      fileBuilder.addSimpleInsertion(body.offset, 'async ');
    }
    for (final call in callsToEdit) {
      final value = call.arguments.arguments.single;
      fileBuilder.addSimpleReplacement(
        SourceRange(call.expression.offset, call.expression.length),
        content.substring(value.offset, value.end),
      );
    }
  });
}

Expression? _futureValueExpression(AstNode node) {
  AstNode? current = node;
  while (current != null) {
    if (current is Expression && futureValueReturnCall(current) != null) {
      return current;
    }
    current = current.parent;
  }
  return null;
}

FunctionBody? _functionBodyFor(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is FunctionBody) return current;
    current = current.parent;
  }
  return null;
}

bool _canEdit(FutureValueReturnCall call, String content) {
  final argument = call.arguments.arguments.single;
  final omittedText =
      content.substring(call.expression.offset, argument.offset) +
      content.substring(argument.end, call.expression.end);
  return !omittedText.contains('//') && !omittedText.contains('/*');
}

List<FutureValueReturnCall> _returnedFutureValues(FunctionBody body) {
  final collector = _ReturnedFutureValueCollector();
  body.accept(collector);
  return collector.calls;
}

class _ReturnedFutureValueCollector() extends RecursiveAstVisitor<void> {
  final calls = <FutureValueReturnCall>[];

  @override
  void visitReturnStatement(ReturnStatement node) {
    final expression = node.expression;
    if (expression != null) {
      final call = futureValueReturnCall(expression);
      if (call != null) calls.add(call);
    }
    super.visitReturnStatement(node);
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    final call = futureValueReturnCall(node.expression);
    if (call != null) calls.add(call);
    super.visitExpressionFunctionBody(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {}
}
