import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:elint/src/rules/sort_member_order/member_order_config.dart';
import 'package:test/test.dart';

void main() {
  group('loadMemberOrderOptions', () {
    late MemoryResourceProvider provider;

    setUp(() {
      provider = MemoryResourceProvider();
      provider.newFile('/project/lib/example.dart', '');
    });

    test('uses default order without a custom list', () {
      provider.newFile('/project/analysis_options.yaml', '');
      final result = loadMemberOrderOptions(
        provider,
        '/project/lib/example.dart',
      );
      expect(result, isA<ValidMemberOrderOptions>());
      expect((result as ValidMemberOrderOptions).order, defaultMemberOrder);
    });

    test('loads nested and package includes with local precedence', () {
      provider.newFile('/project/.dart_tool/package_config.json', '''
{"configVersion": 2, "packages": [
  {"name": "shared", "rootUri": "../shared/", "packageUri": "lib/", "languageVersion": "3.13"}
]}
''');
      provider.newFile('/project/shared/lib/base.yaml', '''
elint:
  diagnostics:
    sort_member_order:
      order: [methods, fields]
''');
      provider.newFile('/project/config/nested.yaml', '''
include: package:shared/base.yaml
elint:
  diagnostics:
    sort_member_order:
      order: [constructors, fields]
''');
      provider.newFile('/project/analysis_options.yaml', '''
include: config/nested.yaml
''');

      final result = loadMemberOrderOptions(
        provider,
        '/project/lib/example.dart',
      );
      expect(result, isA<ValidMemberOrderOptions>());
      expect((result as ValidMemberOrderOptions).order, [
        MemberCategory.constructors,
        MemberCategory.fields,
      ]);
    });

    test('accepts include lists and applies later files in order', () {
      provider.newFile('/project/first.yaml', '''
elint:
  diagnostics:
    sort_member_order:
      order: [fields, getters]
''');
      provider.newFile('/project/second.yaml', '''
elint:
  diagnostics:
    sort_member_order:
      order: [setters, methods]
''');
      provider.newFile('/project/analysis_options.yaml', '''
include: [first.yaml, second.yaml]
''');

      final result = loadMemberOrderOptions(
        provider,
        '/project/lib/example.dart',
      );
      expect((result as ValidMemberOrderOptions).order, [
        MemberCategory.setters,
        MemberCategory.methods,
      ]);
    });

    test('reports unknown categories and duplicates with the yaml path', () {
      provider.newFile('/project/analysis_options.yaml', '''
elint:
  diagnostics:
    sort_member_order:
      order: [fields, constructors, fields, unknown]
''');
      final result = loadMemberOrderOptions(
        provider,
        '/project/lib/example.dart',
      );
      expect(result, isA<InvalidMemberOrderOptions>());
      expect(
        (result as InvalidMemberOrderOptions).optionPath,
        'elint.diagnostics.sort_member_order.order',
      );
      expect(result.filePath, '/project/analysis_options.yaml');
      expect(result.message, contains('duplicate category "fields"'));
    });

    test('reports malformed shapes and include cycles', () {
      provider.newFile('/project/analysis_options.yaml', '''
include: nested.yaml
elint:
  diagnostics:
    sort_member_order:
      order: fields
''');
      provider.newFile(
        '/project/nested.yaml',
        'include: analysis_options.yaml',
      );
      final result = loadMemberOrderOptions(
        provider,
        '/project/lib/example.dart',
      );
      expect(result, isA<InvalidMemberOrderOptions>());
      final invalid = result as InvalidMemberOrderOptions;
      expect(invalid.filePath, '/project/analysis_options.yaml');
      expect(invalid.optionPath, 'include');
      expect(invalid.message, contains('include cycle'));
    });

    test('rejects explicit null for order', () {
      provider.newFile('/project/analysis_options.yaml', '''
elint:
  diagnostics:
    sort_member_order:
      order: null
''');
      final result = loadMemberOrderOptions(
        provider,
        '/project/lib/example.dart',
      );
      expect(result, isA<InvalidMemberOrderOptions>());
      expect(
        (result as InvalidMemberOrderOptions).optionPath,
        'elint.diagnostics.sort_member_order.order',
      );
    });

    test('reports unknown option keys and category names', () {
      provider.newFile('/project/analysis_options.yaml', '''
elint:
  diagnostics:
    sort_member_order:
      categories: [fields]
''');
      final badKey = loadMemberOrderOptions(
        provider,
        '/project/lib/example.dart',
      ) as InvalidMemberOrderOptions;
      expect(
        badKey.optionPath,
        'elint.diagnostics.sort_member_order.categories',
      );

      provider.getFile('/project/analysis_options.yaml').writeAsStringSync('''
elint:
  diagnostics:
    sort_member_order:
      order: [not_a_category]
''');
      final badCategory = loadMemberOrderOptions(
        provider,
        '/project/lib/example.dart',
      ) as InvalidMemberOrderOptions;
      expect(badCategory.message, 'unknown category "not_a_category"');
    });

    test('reports malformed package include URIs as config errors', () {
      provider.newFile(
        '/project/.dart_tool/package_config.json',
        '{"configVersion": 2, "packages": []}',
      );
      provider.newFile(
        '/project/analysis_options.yaml',
        'include: package:bad/%zz.yaml',
      );
      final result = loadMemberOrderOptions(
        provider,
        '/project/lib/example.dart',
      ) as InvalidMemberOrderOptions;
      expect(result.optionPath, 'include');
      expect(result.message, contains('cannot resolve'));
    });

    test('rereads main and included files on each request', () {
      provider.newFile('/project/order.yaml', '''
elint:
  diagnostics:
    sort_member_order:
      order: [methods]
''');
      final main = provider.newFile(
        '/project/analysis_options.yaml',
        'include: order.yaml',
      );
      expect(
        (loadMemberOrderOptions(
          provider,
          '/project/lib/example.dart',
        ) as ValidMemberOrderOptions).order,
        [MemberCategory.methods],
      );
      provider.getFile('/project/order.yaml').writeAsStringSync('''
elint:
  diagnostics:
    sort_member_order:
      order: [getters]
''');
      expect(
        (loadMemberOrderOptions(
          provider,
          '/project/lib/example.dart',
        ) as ValidMemberOrderOptions).order,
        [MemberCategory.getters],
      );
      main.writeAsStringSync('''
elint:
  diagnostics:
    sort_member_order:
      order: [setters]
''');
      expect(
        (loadMemberOrderOptions(
          provider,
          '/project/lib/example.dart',
        ) as ValidMemberOrderOptions).order,
        [MemberCategory.setters],
      );
    });
  });
}
