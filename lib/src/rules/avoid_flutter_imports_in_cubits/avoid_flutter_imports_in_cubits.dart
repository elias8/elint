import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Keeps Flutter SDK imports out of Cubit implementations.
class AvoidFlutterImportsInCubits() extends AnalysisRule {
  static const code = LintCode(
    'avoid_flutter_imports_in_cubits',
    'Cubit implementations should not import Flutter SDK libraries.',
    correctionMessage:
        'Move Flutter-dependent code to the presentation layer or a '
        'framework-neutral service.',
  );

  this
    : super(
        name: 'avoid_flutter_imports_in_cubits',
        description: 'Avoid Flutter SDK imports in Cubit implementations.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext _) {
    registry.addCompilationUnit(this, _Visitor(this));
  }
}

class _Visitor(final AvoidFlutterImportsInCubits rule)
    extends RecursiveAstVisitor<void> {
  final _flutterImports = <StringLiteral>[];
  var _hasCubitImplementation = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element != null && _isCubitImplementation(element)) {
      _hasCubitImplementation = true;
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitCompilationUnit(CompilationUnit node) {
    _flutterImports.clear();
    _hasCubitImplementation = false;
    super.visitCompilationUnit(node);
    if (_hasCubitImplementation) {
      for (final uri in _flutterImports) {
        rule.reportAtNode(uri);
      }
    }
  }

  @override
  void visitImportDirective(ImportDirective node) {
    _addFlutterImport(node.uri);
    for (final configuration in node.configurations) {
      _addFlutterImport(configuration.uri);
    }
    super.visitImportDirective(node);
  }

  void _addFlutterImport(StringLiteral uri) {
    final value = uri.stringValue;
    if (value == null) return;
    final parsedUri = Uri.tryParse(value);
    if (parsedUri != null &&
        parsedUri.scheme == 'package' &&
        parsedUri.pathSegments.firstOrNull == 'flutter') {
      _flutterImports.add(uri);
    }
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
}
