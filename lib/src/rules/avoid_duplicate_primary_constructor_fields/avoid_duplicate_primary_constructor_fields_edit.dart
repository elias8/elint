import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

Future<void> addPrivateFieldEdit(
  AstNode node,
  String content,
  String file,
  ChangeBuilder builder, {
  int? selectionOffset,
  int selectionLength = 0,
}) async {
  final edits = computePrivateFieldEdits(
    node,
    content,
    selectionOffset: selectionOffset,
    selectionLength: selectionLength,
  );
  if (edits.isEmpty) return;

  await builder.addDartFileEdit(file, (fileBuilder) {
    for (final edit in edits) {
      fileBuilder.addSimpleReplacement(
        SourceRange(edit.offset, edit.length),
        edit.replacement,
      );
    }
  });
}

List<({int offset, int length, String replacement})> computePrivateFieldEdits(
  AstNode node,
  String content, {
  int? selectionOffset,
  int selectionLength = 0,
}) {
  AstNode? current = node;
  FormalParameter? parameter;
  while (current != null) {
    if (current is FormalParameter) {
      parameter = current;
      break;
    }
    current = current.parent;
  }
  if (parameter == null) return const [];

  final end = selectionOffset == null
      ? null
      : selectionOffset + selectionLength;
  if (selectionOffset != null &&
      (selectionOffset > parameter.end ||
          end! < parameter.offset ||
          (selectionLength == 0 &&
              (selectionOffset < parameter.offset ||
                  selectionOffset > parameter.end)))) {
    return const [];
  }

  return _computeEdits(parameter, content);
}

List<({int offset, int length, String replacement})> _computeEdits(
  FormalParameter parameter,
  String content,
) {
  final modifier = parameter.constFinalOrVarKeyword;
  final name = parameter.name;
  final alias = _privateAliasFor(parameter, content);
  if (modifier == null || name == null || alias == null) return const [];
  final declarationRange = _fieldDeclarationLineRange(alias, content);
  if (declarationRange == null) return const [];

  return [
    (offset: name.offset, length: name.length, replacement: '_${name.lexeme}'),
    (
      offset: declarationRange.offset,
      length: declarationRange.length,
      replacement: '',
    ),
  ];
}

bool _containsComment(String source) =>
    source.contains('//') || source.contains('/*');

({int offset, int length})? _fieldDeclarationLineRange(
  FieldDeclaration declaration,
  String content,
) {
  final lineStart = content.lastIndexOf('\n', declaration.offset - 1) + 1;
  if (content
      .substring(lineStart, declaration.offset)
      .contains(RegExp(r'[^\t ]'))) {
    return null;
  }

  var end = declaration.end;
  while (end < content.length &&
      (content.codeUnitAt(end) == 0x20 || content.codeUnitAt(end) == 0x09)) {
    end++;
  }
  if (content.startsWith('//', end) || content.startsWith('/*', end)) {
    return null;
  }
  if (content.startsWith('\r\n', end)) {
    end += 2;
  } else if (content.startsWith('\n', end) || content.startsWith('\r', end)) {
    end++;
  }

  var blankLineEnd = end;
  while (blankLineEnd < content.length &&
      (content.codeUnitAt(blankLineEnd) == 0x20 ||
          content.codeUnitAt(blankLineEnd) == 0x09)) {
    blankLineEnd++;
  }
  if (content.startsWith('\r\n', blankLineEnd)) {
    end = blankLineEnd + 2;
  } else if (content.startsWith('\n', blankLineEnd) ||
      content.startsWith('\r', blankLineEnd)) {
    end = blankLineEnd + 1;
  }

  return (offset: lineStart, length: end - lineStart);
}

FieldDeclaration? _privateAliasFor(FormalParameter parameter, String content) {
  final element = parameter.declaredFragment?.element;
  final name = parameter.name?.lexeme;
  if (element is! FieldFormalParameterElement ||
      !element.isDeclaring ||
      name == null ||
      name.startsWith('_')) {
    return null;
  }

  AstNode? current = parameter.parent;
  while (current != null && current is! ClassDeclaration) {
    current = current.parent;
  }
  if (current is! ClassDeclaration ||
      current.namePart is! PrimaryConstructorDeclaration) {
    return null;
  }

  for (final member in current.body.members) {
    if (member is! FieldDeclaration ||
        member.isStatic ||
        member.fields.variables.length != 1 ||
        member.metadata.isNotEmpty) {
      continue;
    }

    final field = member.fields.variables.single;
    final initializer = field.initializer;
    final fieldElement = field.declaredFragment?.element;
    final inducedField = element.field;
    if (field.name.lexeme != '_$name' ||
        initializer is! SimpleIdentifier ||
        initializer.element != element ||
        fieldElement is! FieldElement ||
        inducedField == null ||
        fieldElement.type != inducedField.type ||
        fieldElement.isFinal != inducedField.isFinal ||
        fieldElement.isLate ||
        _containsComment(content.substring(member.offset, member.end))) {
      continue;
    }

    final precedingTrivia = content.substring(
      member.parent!.beginToken.end,
      member.offset,
    );
    if (_containsComment(precedingTrivia)) continue;

    return member;
  }
  return null;
}
