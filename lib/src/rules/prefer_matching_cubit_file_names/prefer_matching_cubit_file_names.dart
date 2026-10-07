import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Matches Cubit class names to their Dart file names.
class PreferMatchingCubitFileNames() extends AnalysisRule {
  static const code = LintCode(
    'prefer_matching_cubit_file_names',
    'Cubit class name should match its file name.',
    correctionMessage:
        'Move the declaration to a file named with the class name in '
        'snake_case.',
  );

  this
    : super(
        name: 'prefer_matching_cubit_file_names',
        description: 'Do match Cubit class names to snake_case file names.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext _) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

class _Visitor(final PreferMatchingCubitFileNames rule)
    extends RecursiveAstVisitor<void> {
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    final fileName = _fileName(node);
    final name = node.namePart.typeName;
    if (element != null &&
        !name.isSynthetic &&
        _isCubitImplementation(element) &&
        fileName != null &&
        fileName != '${_toSnakeCase(name.lexeme)}.dart') {
      rule.reportAtToken(name);
    }

    super.visitClassDeclaration(node);
  }

  String? _fileName(ClassDeclaration node) {
    final unit = node.thisOrAncestorOfType<CompilationUnit>();
    final segments = unit?.declaredFragment?.source.uri.pathSegments;
    return segments == null || segments.isEmpty ? null : segments.last;
  }

  bool _isCubitImplementation(ClassElement element) {
    final visited = <ClassElement>{element};
    final superclass = element.supertype?.element;
    ClassElement? current = superclass is ClassElement ? superclass : null;

    while (current != null && visited.add(current)) {
      if (current.name == 'Cubit' &&
          current.library.uri.scheme == 'package' &&
          current.library.uri.pathSegments.firstOrNull == 'bloc') {
        return true;
      }
      final superclass = current.supertype?.element;
      current = superclass is ClassElement ? superclass : null;
    }

    return false;
  }

  String _toSnakeCase(String name) {
    return name
        .replaceAllMapped(
          RegExp('([A-Z]+)([A-Z][a-z])'),
          (match) => '${match[1]}_${match[2]}',
        )
        .replaceAllMapped(
          RegExp('([a-z0-9])([A-Z])'),
          (match) => '${match[1]}_${match[2]}',
        )
        .toLowerCase();
  }
}
