import 'dart:io';

import 'package:adaptable_remote_config/src/cli/setup.dart';

/// `dart run adaptable_remote_config` — interactive setup for force updates.
void main(List<String> args) => exit(runCli(args));
