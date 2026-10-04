import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

import 'member_order_config.dart';
import 'sort_member_order.dart';

({Iterable<ClassMember> members, int startOffset, Token rightBracket})?
_declarationBody(AstNode declaration) {
  if (declaration is ClassDeclaration) {
    final body = declaration.body;
    if (body is BlockClassBody) {
      return (
        members: body.members,
        startOffset: body.leftBracket.end,
        rightBracket: body.rightBracket,
      );
    }
  }
  if (declaration is EnumDeclaration) {
    final body = declaration.body;
    if (body is BlockEnumBody) {
      final semicolon = body.semicolon;
      if (semicolon == null) return null;
      return (
        members: body.members,
        startOffset: semicolon.end,
        rightBracket: body.rightBracket,
      );
    }
  }
  return null;
}

AstNode? _enclosingDeclaration(AstNode node) {
  AstNode? current = node;
  while (current != null) {
    if (current is ClassDeclaration || current is EnumDeclaration) {
      return current;
    }
    current = current.parent;
  }
  return null;
}

bool _hasTrailingComment(String trivia) {
  final newline = trivia.indexOf('\n');
  final firstLine = newline == -1 ? trivia : trivia.substring(0, newline);
  return firstLine.contains('//') || firstLine.contains('/*');
}

({int offset, int length, String replacement})? computeMemberOrderEdit(
  AstNode node,
  String content,
  ResourceProvider provider,
  String file,
) {
  final options = loadMemberOrderOptions(provider, file);
  if (options is! ValidMemberOrderOptions || options.order.length <= 1) {
    return null;
  }
  final declaration = _enclosingDeclaration(node);
  if (declaration == null) return null;
  final body = _declarationBody(declaration);
  if (body == null) return null;
  final originalMembers = List<ClassMember>.of(body.members);
  final plan = planMemberOrder(originalMembers, options.order);
  if (plan.firstChangedMember == null) return null;

  final memberText = <ClassMember, String>{};
  var previousEnd = body.startOffset;
  for (final member in originalMembers) {
    final leadingTrivia = content.substring(previousEnd, member.offset);
    if (_hasTrailingComment(leadingTrivia)) return null;
    memberText[member] = content.substring(previousEnd, member.end);
    previousEnd = member.end;
  }
  final trailingTrivia = content.substring(
    previousEnd,
    body.rightBracket.offset,
  );
  if (_hasTrailingComment(trailingTrivia)) return null;

  final replacement = StringBuffer()
    ..writeAll(plan.members.map((member) => memberText[member]))
    ..write(trailingTrivia);
  return (
    offset: body.startOffset,
    length: body.rightBracket.offset - body.startOffset,
    replacement: replacement.toString(),
  );
}

Future<void> addMemberOrderEdit(
  AstNode node,
  String content,
  String file,
  ResourceProvider provider,
  ChangeBuilder builder,
) async {
  final edit = computeMemberOrderEdit(node, content, provider, file);
  if (edit == null) return;
  await builder.addDartFileEdit(file, (fileBuilder) {
    fileBuilder.addSimpleReplacement(
      SourceRange(edit.offset, edit.length),
      edit.replacement,
    );
  });
}
