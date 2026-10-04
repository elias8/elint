import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'member_order_config.dart';

/// Orders selected class and enum members according to analysis options.
class SortMemberOrder() extends AnalysisRule {
  static const code = LintCode('sort_member_order', '{0}');

  this
    : super(
        name: 'sort_member_order',
        description: 'Orders selected members in classes and enums.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry.addCompilationUnit(this, visitor);
    registry.addClassDeclaration(this, visitor);
    registry.addEnumDeclaration(this, visitor);
  }
}

class _Visitor(final SortMemberOrder rule, final RuleContext context)
    extends SimpleAstVisitor<void> {
  MemberOrderOptionsResult? _options;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final unit = context.currentUnit;
    if (unit == null) return;
    _options = loadMemberOrderOptions(unit.file.provider, unit.file.path);
    final options = _options;
    if (options case InvalidMemberOrderOptions(
      :final filePath,
      :final optionPath,
      :final message,
    )) {
      rule.reportAtNode(
        node,
        arguments: ['Invalid $filePath ($optionPath): $message'],
      );
    }
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _reportOrder(node.body.members);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _reportOrder(node.body.members);
  }

  void _reportOrder(Iterable<ClassMember> members) {
    final options = _options;
    if (options is! ValidMemberOrderOptions || options.order.length <= 1) {
      return;
    }
    final plan = planMemberOrder(members, options.order);
    if (plan.firstChangedMember case final member?) {
      rule.reportAtNode(member, arguments: ['Members are out of order.']);
    }
  }
}

({List<ClassMember> members, ClassMember? firstChangedMember}) planMemberOrder(
  Iterable<ClassMember> source,
  List<MemberCategory> order,
) {
  final members = List<ClassMember>.of(source);
  if (order.length <= 1) {
    return (members: members, firstChangedMember: null);
  }

  final ranks = {for (var i = 0; i < order.length; i++) order[i]: i};
  final slots = <int>[];
  final selected = <({int index, ClassMember member, int rank})>[];
  for (var index = 0; index < members.length; index++) {
    final member = members[index];
    final category = memberCategory(member);
    final rank = category == null ? null : ranks[category];
    if (rank == null) continue;
    slots.add(index);
    selected.add((index: index, member: member, rank: rank));
  }
  if (selected.length <= 1) {
    return (members: members, firstChangedMember: null);
  }

  selected.sort((a, b) {
    final rankOrder = a.rank.compareTo(b.rank);
    return rankOrder == 0 ? a.index.compareTo(b.index) : rankOrder;
  });
  final result = List<ClassMember>.of(members);
  for (var i = 0; i < slots.length; i++) {
    result[slots[i]] = selected[i].member;
  }
  for (var i = 0; i < members.length; i++) {
    if (members[i] != result[i]) {
      return (members: result, firstChangedMember: members[i]);
    }
  }
  return (members: result, firstChangedMember: null);
}

MemberCategory? memberCategory(ClassMember member) => switch (member) {
  FieldDeclaration() => MemberCategory.fields,
  ConstructorDeclaration() => MemberCategory.constructors,
  MethodDeclaration(isGetter: true) => MemberCategory.getters,
  MethodDeclaration(isSetter: true) => MemberCategory.setters,
  MethodDeclaration() => MemberCategory.methods,
  _ => null,
};
