import 'package:analyzer/file_system/file_system.dart';
import 'package:package_config/package_config.dart';
import 'package:yaml/yaml.dart';

enum MemberCategory() {
  fields,
  constructors,
  getters,
  setters,
  methods,
}

sealed class MemberOrderOptionsResult();

final class ValidMemberOrderOptions(Iterable<MemberCategory> categories)
    extends MemberOrderOptionsResult {
  final List<MemberCategory> order = List.unmodifiable(categories);
}

final class InvalidMemberOrderOptions(
  final String filePath,
  final String optionPath,
  final String message,
) extends MemberOrderOptionsResult;

final class _MemberOrderError(final String optionPath, final String message);

const defaultMemberOrder = [MemberCategory.fields, MemberCategory.constructors];

MemberOrderOptionsResult loadMemberOrderOptions(
  ResourceProvider provider,
  String dartFile,
) {
  final pathContext = provider.pathContext;
  final absoluteFile = pathContext.normalize(dartFile);
  final packageConfig = _loadPackageConfig(provider, absoluteFile);
  final optionsFile = _findOptionsFile(provider, absoluteFile);
  if (optionsFile == null) {
    return ValidMemberOrderOptions(defaultMemberOrder);
  }

  final merged = <MemberCategory>[...defaultMemberOrder];
  final visited = <String>{};
  final result = _readOptions(
    provider,
    optionsFile,
    packageConfig,
    visited,
    merged,
  );
  return result ?? ValidMemberOrderOptions(merged);
}

PackageConfig? _loadPackageConfig(ResourceProvider provider, String dartFile) {
  final pathContext = provider.pathContext;
  var directory = pathContext.dirname(dartFile);
  while (true) {
    final configPath = pathContext.join(
      directory,
      '.dart_tool',
      'package_config.json',
    );
    final file = provider.getFile(configPath);
    if (file.exists) {
      try {
        return PackageConfig.parseString(
          file.readAsStringSync(),
          pathContext.toUri(configPath),
        );
      } on FormatException {
        return null;
      } on PackageConfigError {
        return null;
      }
    }
    final parent = pathContext.dirname(directory);
    if (parent == directory) return null;
    directory = parent;
  }
}

String? _findOptionsFile(ResourceProvider provider, String dartFile) {
  final pathContext = provider.pathContext;
  var directory = pathContext.dirname(dartFile);
  while (true) {
    final path = pathContext.join(directory, 'analysis_options.yaml');
    if (provider.getFile(path).exists) return path;
    final parent = pathContext.dirname(directory);
    if (parent == directory) return null;
    directory = parent;
  }
}

InvalidMemberOrderOptions? _readOptions(
  ResourceProvider provider,
  String path,
  PackageConfig? packageConfig,
  Set<String> visited,
  List<MemberCategory> merged,
) {
  final pathContext = provider.pathContext;
  final normalizedPath = pathContext.normalize(path);
  if (!visited.add(normalizedPath)) {
    return InvalidMemberOrderOptions(
      normalizedPath,
      'include',
      'include cycle',
    );
  }
  final file = provider.getFile(normalizedPath);
  if (!file.exists) {
    visited.remove(normalizedPath);
    return InvalidMemberOrderOptions(path, 'include', 'file not found');
  }

  Object? yaml;
  try {
    yaml = loadYaml(file.readAsStringSync());
  } on YamlException catch (error) {
    visited.remove(normalizedPath);
    return InvalidMemberOrderOptions(
      normalizedPath,
      'analysis_options.yaml',
      error.message,
    );
  }
  if (yaml == null) {
    visited.remove(normalizedPath);
    return null;
  }
  if (yaml is! YamlMap) {
    visited.remove(normalizedPath);
    return InvalidMemberOrderOptions(
      normalizedPath,
      'analysis_options.yaml',
      'must be a map',
    );
  }

  final includeValue = yaml['include'];
  final includes = switch (includeValue) {
    null => const <String>[],
    final String value => [value],
    final YamlList values when values.every((value) => value is String) =>
      values.cast<String>(),
    _ => null,
  };
  if (includes == null) {
    visited.remove(normalizedPath);
    return InvalidMemberOrderOptions(
      normalizedPath,
      'include',
      'must be a path or list of paths',
    );
  }
  for (final include in includes) {
    final includePath = _resolveInclude(
      provider,
      normalizedPath,
      include,
      packageConfig,
    );
    if (includePath == null) {
      visited.remove(normalizedPath);
      return InvalidMemberOrderOptions(
        normalizedPath,
        'include',
        'cannot resolve $include',
      );
    }
    final error = _readOptions(
      provider,
      includePath,
      packageConfig,
      visited,
      merged,
    );
    if (error != null) {
      visited.remove(normalizedPath);
      return error;
    }
  }

  final error = _mergeMemberOrder(yaml, merged);
  visited.remove(normalizedPath);
  if (error != null) {
    return InvalidMemberOrderOptions(
      normalizedPath,
      error.optionPath,
      error.message,
    );
  }
  return null;
}

String? _resolveInclude(
  ResourceProvider provider,
  String includingFile,
  String include,
  PackageConfig? packageConfig,
) {
  final context = provider.pathContext;
  if (include.startsWith('package:')) {
    if (packageConfig == null) return null;
    final packageUri = Uri.tryParse(include);
    if (packageUri == null) return null;
    final uri = packageConfig.resolve(packageUri);
    return uri == null ? null : context.normalize(context.fromUri(uri));
  }
  final includingDirectory = context.dirname(includingFile);
  final resolved = context.isAbsolute(include)
      ? include
      : context.join(includingDirectory, include);
  return context.normalize(resolved);
}

_MemberOrderError? _mergeMemberOrder(
  YamlMap yaml,
  List<MemberCategory> merged,
) {
  const optionsPath = 'elint.diagnostics.sort_member_order';
  final elint = yaml['elint'];
  if (elint == null) return null;
  if (elint is! YamlMap) {
    return _MemberOrderError('elint', 'must be a map');
  }
  final diagnostics = elint['diagnostics'];
  if (diagnostics == null) return null;
  if (diagnostics is! YamlMap) {
    return _MemberOrderError('elint.diagnostics', 'must be a map');
  }
  final rawOptions = diagnostics['sort_member_order'];
  if (rawOptions == null) return null;
  if (rawOptions is! YamlMap) {
    return _MemberOrderError(optionsPath, 'must be a map');
  }
  final unknownKeys = rawOptions.keys.where((key) => key != 'order');
  if (unknownKeys.isNotEmpty) {
    return _MemberOrderError(
      '$optionsPath.${unknownKeys.first}',
      'unknown option',
    );
  }
  final rawOrder = rawOptions['order'];
  if (rawOrder == null) {
    if (!rawOptions.containsKey('order')) return null;
    return _MemberOrderError(
      '$optionsPath.order',
      'must be a list of categories',
    );
  }
  if (rawOrder is! YamlList || rawOrder.any((value) => value is! String)) {
    return _MemberOrderError(
      '$optionsPath.order',
      'must be a list of categories',
    );
  }

  final order = <MemberCategory>[];
  final seen = <MemberCategory>{};
  for (final name in rawOrder.cast<String>()) {
    final category = MemberCategory.values.where((value) => value.name == name);
    if (category.isEmpty) {
      return _MemberOrderError(
        '$optionsPath.order',
        'unknown category "$name"',
      );
    }
    final value = category.single;
    if (!seen.add(value)) {
      return _MemberOrderError(
        '$optionsPath.order',
        'duplicate category "$name"',
      );
    }
    order.add(value);
  }
  merged
    ..clear()
    ..addAll(order);
  return null;
}
