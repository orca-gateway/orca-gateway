import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:orca_gateway_cli/src/commands/plugin_add.dart';
import 'package:orca_gateway_cli/src/commands/plugin_remove.dart';
import 'package:orca_gateway_cli/src/commands/plugin_doctor.dart';
import 'package:orca_gateway_cli/src/commands/plugin_create.dart';
import 'package:orca_gateway_cli/src/commands/plugin_generate.dart';
import 'package:orca_gateway_cli/src/commands/plugin_build.dart';

void main(List<String> args) async {
  final runner = CommandRunner<void>(
    'orca',
    'Orca Gateway CLI — manage plugins, native config, and scaffolding.',
  )..addCommand(PluginCommand());

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  }
}

/// Parent command for all plugin subcommands.
class PluginCommand extends Command<void> {
  @override
  final name = 'plugin';

  @override
  final description = 'Manage Orca Gateway plugins.';

  PluginCommand() {
    addSubcommand(PluginAddCommand());
    addSubcommand(PluginRemoveCommand());
    addSubcommand(PluginDoctorCommand());
    addSubcommand(PluginCreateCommand());
    addSubcommand(PluginGenerateCommand());
    addSubcommand(PluginBuildCommand());
  }
}
