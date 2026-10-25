import 'dart:convert';
import 'dart:io';

import 'answers.dart';

/// Runs a command; swapped for a fake in tests.
typedef RunCommand =
    ProcessResult Function(
      String executable,
      List<String> args, {
      String? workingDirectory,
    });

ProcessResult _runForReal(
  String executable,
  List<String> args, {
  String? workingDirectory,
}) => Process.runSync(
  executable,
  args,
  workingDirectory: workingDirectory,
  // `firebase` is a .cmd shim on Windows.
  runInShell: Platform.isWindows,
);

/// Thrown with a message meant for the user.
class PublishException implements Exception {
  const PublishException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The parameters to add and the ones that were already there.
class TemplateMerge {
  const TemplateMerge(this.template, this.added, this.existing);

  final Map<String, dynamic> template;
  final List<ParamSpec> added;
  final List<String> existing;
}

/// Adds the missing [wanted] parameters to [current] and never touches a
/// parameter that already exists, wherever it lives (top level or a folder).
TemplateMerge mergeParameters(
  Map<String, dynamic> current,
  List<ParamSpec> wanted,
) {
  final template = jsonDecode(jsonEncode(current)) as Map<String, dynamic>;
  final parameters =
      (template['parameters'] ??= <String, dynamic>{}) as Map<String, dynamic>;
  final known = {
    ...parameters.keys,
    for (final group
        in (template['parameterGroups'] as Map<String, dynamic>? ?? {}).values)
      ...((group as Map<String, dynamic>)['parameters'] as Map<String, dynamic>? ??
              {})
          .keys,
  };
  final added = <ParamSpec>[];
  final existing = <String>[];
  for (final spec in wanted) {
    if (known.contains(spec.name)) {
      existing.add(spec.name);
      continue;
    }
    parameters[spec.name] = {
      'defaultValue': {'value': spec.example},
      'valueType': spec.type == 'Boolean' ? 'BOOLEAN' : 'STRING',
    };
    added.add(spec);
  }
  return TemplateMerge(template, added, existing);
}

/// The Firebase project id from `lib/firebase_options.dart` or `.firebaserc`.
String? readFirebaseProjectId(Directory project) {
  final options = File('${project.path}/lib/firebase_options.dart');
  if (options.existsSync()) {
    final match = RegExp(
      r"projectId:\s*'([^']+)'",
    ).firstMatch(options.readAsStringSync());
    if (match != null) return match.group(1);
  }
  final rc = File('${project.path}/.firebaserc');
  if (rc.existsSync()) {
    try {
      final json = jsonDecode(rc.readAsStringSync()) as Map<String, dynamic>;
      return (json['projects'] as Map<String, dynamic>?)?['default'] as String?;
    } on FormatException {
      return null;
    }
  }
  return null;
}

/// Reads and updates a project's Remote Config through the Firebase CLI, so no
/// service-account key is needed: it uses the login `flutterfire configure`
/// already required.
class RemoteConfigPublisher {
  RemoteConfigPublisher({RunCommand? run, Directory? scratch})
    : _run = run ?? _runForReal,
      _scratch = scratch;

  final RunCommand _run;
  final Directory? _scratch;

  bool get isAvailable {
    try {
      return _run('firebase', ['--version']).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  /// The live template (parameters, folders, conditions).
  Map<String, dynamic> fetch(String projectId) {
    final dir = _tempDir();
    try {
      final file = File('${dir.path}/current.json');
      final result = _run('firebase', [
        'remoteconfig:get',
        '--project',
        projectId,
        '-o',
        file.path,
      ]);
      if (result.exitCode != 0 || !file.existsSync()) {
        throw PublishException(
          'Could not read Remote Config for "$projectId": ${_why(result)}',
        );
      }
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } finally {
      dir.deleteSync(recursive: true);
    }
  }

  /// Publishes [template]. Refuses if the live template is not [basedOn]
  /// any more, because the CLI would silently overwrite someone's change.
  void publish(
    String projectId,
    Map<String, dynamic> template, {
    required Map<String, dynamic> basedOn,
  }) {
    if (jsonEncode(fetch(projectId)) != jsonEncode(basedOn)) {
      throw const PublishException(
        'Remote Config changed while setting up. Nothing was published; '
        'run the setup again.',
      );
    }
    final dir = _tempDir();
    try {
      File('${dir.path}/firebase.json').writeAsStringSync(
        jsonEncode({
          'remoteconfig': {'template': 'remoteconfig.template.json'},
        }),
      );
      File('${dir.path}/remoteconfig.template.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(template),
      );
      final result = _run(
        'firebase',
        [
          'deploy',
          '--only',
          'remoteconfig',
          '--project',
          projectId,
          '--non-interactive',
        ],
        workingDirectory: dir.path,
      );
      if (result.exitCode != 0) {
        throw PublishException('Publishing failed: ${_why(result)}');
      }
    } finally {
      dir.deleteSync(recursive: true);
    }
  }

  Directory _tempDir() =>
      (_scratch ?? Directory.systemTemp).createTempSync('arc_rc_');

  String _why(ProcessResult result) {
    final text = '${result.stderr}\n${result.stdout}'.trim();
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty);
    return lines.isEmpty ? 'exit code ${result.exitCode}' : lines.last.trim();
  }
}
