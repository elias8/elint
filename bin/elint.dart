import 'dart:io';

import 'package:elint/src/cli/cli.dart';

Future<void> main(List<String> args) async {
  final result = await runElintCommand(
    args,
    workingDirectory: Directory.current.path,
  );
  stdout.write(result.output);
  exitCode = result.exitCode;
}
