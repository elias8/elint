import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

Future<void> addPreferAsyncAwaitEdit(
  AstNode node,
  String content,
  String file,
  ChangeBuilder builder, {
  int? selectionOffset,
  int selectionLength = 0,
}) async {
  final call = _preferAsyncAwaitCall(node);
  if (call == null || !_canRewrite(call, content)) return;
  final indent = _lineIndent(content, call.statement.offset);
  if (indent == null) return;

  if (selectionOffset != null) {
    final selectionEnd = selectionOffset + selectionLength;
    if (selectionOffset > call.invocation.end ||
        selectionEnd < call.invocation.offset ||
        (selectionLength == 0 &&
            (selectionOffset < call.invocation.offset ||
                selectionOffset > call.invocation.end))) {
      return;
    }
  }

  final target = call.invocation.target!;
  final callbackBody = call.callback.body as ExpressionFunctionBody;
  final callbackExpression = content.substring(
    callbackBody.expression.offset,
    callbackBody.expression.end,
  );
  final replacement =
      'final ${call.parameter.name!.lexeme} = await '
      '${content.substring(target.offset, target.end)};\n'
      '${indent}return $callbackExpression;';

  await builder.addDartFileEdit(file, (fileBuilder) {
    fileBuilder.addSimpleReplacement(
      SourceRange(call.statement.offset, call.statement.length),
      replacement,
    );
  });
}

_PreferAsyncAwaitCall? _preferAsyncAwaitCall(AstNode node) {
  final invocation = switch (node) {
    MethodInvocation() => node,
    _ => node.thisOrAncestorOfType<MethodInvocation>(),
  };
  if (invocation == null || !_isPreferAsyncAwaitInvocation(invocation)) {
    return null;
  }

  final statement = invocation.parent;
  if (statement is! ReturnStatement ||
      !identical(statement.expression, invocation) ||
      statement.parent is! Block) {
    return null;
  }

  final body = _functionBodyFor(statement);
  if (body == null || !body.isAsynchronous || body.isGenerator) return null;

  final arguments = invocation.argumentList.arguments;
  if (arguments.length != 1 || arguments.single is NamedArgument) return null;
  final callback = arguments.single;
  if (callback is! FunctionExpression ||
      callback.body is! ExpressionFunctionBody ||
      callback.body.isAsynchronous ||
      (callback.parameters?.parameters.length ?? 0) != 1) {
    return null;
  }

  final parameter = callback.parameters!.parameters.single;
  if (parameter is! RegularFormalParameter ||
      parameter.functionTypedSuffix != null ||
      parameter.defaultClause != null ||
      parameter.type != null ||
      parameter.name == null ||
      invocation.target == null) {
    return null;
  }

  final parameterElement = parameter.declaredFragment?.element;
  if (parameterElement == null) return null;
  final references = _ParameterReferences(parameterElement);
  callback.body.accept(references);
  if (references.count == 0) return null;

  final invocationCount = _PreferAsyncAwaitCounter();
  statement.accept(invocationCount);
  if (invocationCount.count != 1) return null;

  final names = _IdentifierNames(parameter.name!.lexeme, invocation);
  body.accept(names);
  if (names.found) return null;

  return (
    statement: statement,
    invocation: invocation,
    callback: callback,
    parameter: parameter,
  );
}

bool _canRewrite(_PreferAsyncAwaitCall call, String content) {
  final source = content.substring(call.statement.offset, call.statement.end);
  return !source.contains('//') && !source.contains('/*');
}

FunctionBody? _functionBodyFor(AstNode node) =>
    node.thisOrAncestorOfType<FunctionBody>();

String? _lineIndent(String content, int offset) {
  final lineStart = content.lastIndexOf('\n', offset - 1) + 1;
  final prefix = content.substring(lineStart, offset);
  return prefix.trim().isEmpty ? prefix : null;
}

bool _isPreferAsyncAwaitInvocation(MethodInvocation node) {
  final method = node.methodName.element;
  final owner = method?.enclosingElement;
  return node.methodName.name == 'then' &&
      owner?.name == 'Future' &&
      (owner?.library?.isDartAsync ?? false);
}

typedef _PreferAsyncAwaitCall = ({
  ReturnStatement statement,
  MethodInvocation invocation,
  FunctionExpression callback,
  RegularFormalParameter parameter,
});

class _PreferAsyncAwaitCounter() extends RecursiveAstVisitor<void> {
  var count = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isPreferAsyncAwaitInvocation(node)) count++;
    super.visitMethodInvocation(node);
  }
}

class _IdentifierNames(final String name, final MethodInvocation excluded)
    extends RecursiveAstVisitor<void> {
  var found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!identical(node, excluded)) super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == name) found = true;
  }
}

class _ParameterReferences(final FormalParameterElement parameter)
    extends RecursiveAstVisitor<void> {
  var count = 0;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.element == parameter) count++;
  }
}
