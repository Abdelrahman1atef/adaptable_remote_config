import 'dart:io';

import 'answers.dart';
import 'generator.dart';
import 'patcher.dart';
import 'prompter.dart';
import 'remote_config_publisher.dart';

const _usage = '''
Sets up remote-controlled app updates (force / optional) in this Flutter app.

Usage: dart run adaptable_remote_config [options]

  -y, --yes          No questions: Firebase, force + optional, Android + iOS
  --source <name>    firebase | http | custom
  --mode <name>      both | force | optional
  --url <url>        JSON file URL (with --source http)
  --prefix <name>    Name the keys <name>_android_version... (several apps, one project)
  --group <name>     Put the keys in this Firebase console folder (default: the prefix)
  --no-group         Do not use a console folder
  --publish          Create the Remote Config parameters in Firebase without asking
  --no-publish       Only print the parameters to create
  --project <id>     Firebase project id (default: read from firebase_options.dart)
  --dir <path>       Flutter project to set up (default: current directory)
  --out <path>       Generated file (default: lib/app_update.dart)
  -h, --help         Show this help
''';

/// Thrown to stop the wizard with a message and a non-zero exit code.
class SetupAbort implements Exception {
  const SetupAbort(this.message, [this.code = 64]);
  final String message;
  final int code;
}

/// Answers every question with its default (the `--yes` mode).
class DefaultsPrompter implements Prompter {
  const DefaultsPrompter();

  @override
  T select<T>(String question, List<Choice<T>> options, {int initial = 0}) =>
      options[initial].value;

  @override
  List<T> multiSelect<T>(
    String question,
    List<Choice<T>> options, {
    Set<T> initial = const {},
  }) => [
    for (final o in options)
      if (initial.contains(o.value)) o.value,
  ];

  @override
  String input(
    String question, {
    String defaultValue = '',
    String? Function(String value)? validate,
  }) {
    final error = validate?.call(defaultValue);
    if (error != null) throw SetupAbort('$question: $error');
    return defaultValue;
  }

  @override
  bool confirm(String question, {bool defaultValue = true}) => defaultValue;
}

/// Installs a pub dependency; returns true on success.
typedef AddDependency = bool Function(Directory project, String package);

bool _flutterPubAdd(Directory project, String package) => Process.runSync(
  'flutter',
  ['pub', 'add', package],
  workingDirectory: project.path,
  runInShell: true,
).exitCode == 0;

/// Entry point used by `bin/adaptable_remote_config.dart`.
int runCli(
  List<String> args, {
  Prompter? prompter,
  StringSink? out,
  AddDependency addDependency = _flutterPubAdd,
  RemoteConfigPublisher? publisher,
}) {
  final sink = out ?? stdout;
  String? dir;
  String? output;
  String? source;
  String? mode;
  String? url;
  String? project;
  String? prefix;
  String? group;
  var noGroup = false;
  bool? publish;
  var yes = false;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    final hasValue = i + 1 < args.length;
    if (arg == '-h' || arg == '--help') {
      sink.write(_usage);
      return 0;
    } else if (arg == '-y' || arg == '--yes') {
      yes = true;
    } else if (arg == '--dir' && hasValue) {
      dir = args[++i];
    } else if (arg == '--out' && hasValue) {
      output = args[++i];
    } else if (arg == '--source' && hasValue) {
      source = args[++i];
    } else if (arg == '--mode' && hasValue) {
      mode = args[++i];
    } else if (arg == '--prefix' && hasValue) {
      prefix = args[++i];
    } else if (arg == '--group' && hasValue) {
      group = args[++i];
    } else if (arg == '--no-group') {
      noGroup = true;
    } else if (arg == '--publish') {
      publish = true;
    } else if (arg == '--no-publish') {
      publish = false;
    } else if (arg == '--project' && hasValue) {
      project = args[++i];
    } else if (arg == '--url' && hasValue) {
      url = args[++i];
    } else {
      sink.writeln('Unknown option: $arg\n');
      sink.write(_usage);
      return 64;
    }
  }
  try {
    return runSetup(
      yes ? const DefaultsPrompter() : (prompter ?? TerminalPrompter()),
      sink,
      projectDir: Directory(dir ?? '.'),
      outputPath: output,
      preset: SetupPreset(
        source: _parse(ConfigSource.values, source, '--source'),
        mode: _modeFrom(mode),
        url: url,
        prefix: prefix,
        group: group,
        noGroup: noGroup,
      ),
      addDependency: addDependency,
      yes: yes,
      publisher: publisher ?? RemoteConfigPublisher(),
      projectId: project,
      publish: publish,
    );
  } on SetupAbort catch (e) {
    sink.writeln(e.message);
    return e.code;
  }
}

UpdateMode? _modeFrom(String? value) => switch (value) {
  null => null,
  'both' => UpdateMode.both,
  'force' => UpdateMode.forceOnly,
  'optional' => UpdateMode.optionalOnly,
  _ => throw const SetupAbort('--mode: use both, force or optional'),
};

T? _parse<T extends Enum>(List<T> values, String? name, String flag) {
  if (name == null) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw SetupAbort('$flag: unknown value "$name"');
}

/// Answers given as command-line flags, so those questions are skipped.
class SetupPreset {
  const SetupPreset({
    this.source,
    this.mode,
    this.url,
    this.prefix,
    this.group,
    this.noGroup = false,
  });
  final ConfigSource? source;
  final UpdateMode? mode;
  final String? url;
  final String? prefix;
  final String? group;
  final bool noGroup;
}

/// Asks the questions, writes the file, edits the app and prints what is left.
int runSetup(
  Prompter ask,
  StringSink out, {
  required Directory projectDir,
  String? outputPath,
  SetupPreset preset = const SetupPreset(),
  AddDependency addDependency = _flutterPubAdd,
  bool yes = false,
  RemoteConfigPublisher? publisher,
  String? projectId,
  bool? publish,
}) {
  final pubspec = File('${projectDir.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    out.writeln('No pubspec.yaml in ${projectDir.absolute.path}.');
    out.writeln('Run this from the root of your Flutter app.');
    return 66;
  }
  final pubspecText = pubspec.readAsStringSync();
  final name = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspecText);
  final appName = name?.group(1) ?? 'my_app';

  out.writeln('\nadaptable_remote_config setup\n');
  final existing = _firstFileWith(
    projectDir,
    'RemoteConfigController(',
    skip: outputPath ?? 'lib/app_update.dart',
  );
  if (existing != null &&
      !ask.confirm(
        'This app already creates a RemoteConfigController ($existing). '
        'Set it up again anyway?',
        defaultValue: false,
      )) {
    out.writeln('Nothing changed: $existing already sets this up.');
    return 0;
  }
  final answers = _collect(
    ask,
    appName,
    outputPath ?? 'lib/app_update.dart',
    preset,
  );

  final file = File('${projectDir.path}/${answers.outputPath}');
  final write = !file.existsSync() ||
      ask.confirm(
        '${answers.outputPath} exists. Overwrite it?',
        defaultValue: false,
      );
  if (write) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(appUpdateSource(answers));
    out.writeln('+ created ${answers.outputPath}');
  } else {
    out.writeln('- kept your existing ${answers.outputPath}');
  }

  final importPath = _importPath(appName, answers.outputPath);
  final edits = _planEdits(projectDir, answers, appName, importPath);
  final changed = edits.where((e) => e.result.changed).toList();
  var applied = false;
  if (changed.isNotEmpty) {
    for (final edit in changed) {
      out.writeln('  ${edit.path}: ${edit.result.note}');
    }
    applied = ask.confirm('Apply these edits to your app?');
    // Edits to one file all carry its final text, so write each file once.
    final texts = {for (final e in changed) e.path: e.result.source!};
    for (final entry in applied ? texts.entries : const <MapEntry<String, String>>[]) {
      File('${projectDir.path}/${entry.key}').writeAsStringSync(entry.value);
      out.writeln('+ edited ${entry.key}');
    }
  }
  for (final e in edits.where((e) => !e.result.changed && !e.result.alreadyDone)) {
    out.writeln('  ${e.path}: ${e.result.note}');
  }

  _ensureFirebase(ask, out, projectDir, answers, pubspecText, addDependency);

  bool done(_Kind kind) => edits.any(
    (e) => e.kind == kind && (e.result.alreadyDone || (e.result.changed && applied)),
  );
  final left = nextSteps(
    answers,
    importPath: importPath,
    firebaseDone: done(_Kind.firebase),
    gateDone: done(_Kind.gate),
  );
  if (left.isNotEmpty) out.writeln('\nStill to do by hand:\n\n$left');
  final published = answers.source == ConfigSource.firebase &&
      publish != false &&
      _publishParameters(
        ask,
        out,
        answers,
        publisher ?? RemoteConfigPublisher(),
        projectId ?? readFirebaseProjectId(projectDir),
        alwaysYes: publish == true,
        interactive: !yes,
      );
  if (!published) out.writeln('\n${remoteValuesGuide(answers)}');
  out.writeln(
    'The app already works with the defaults in lib/app_update.dart; the '
    'values above let you change it later without a release.',
  );
  return 0;
}

/// Adds the missing parameters to the Firebase project. Returns true when the
/// project has them all afterwards (so the manual guide is not needed).
bool _publishParameters(
  Prompter ask,
  StringSink out,
  SetupAnswers answers,
  RemoteConfigPublisher publisher,
  String? projectId, {
  required bool alwaysYes,
  required bool interactive,
}) {
  // Writing to a live project is opt-in when there are no questions.
  if (!interactive && !alwaysYes) return false;
  if (projectId == null) {
    out.writeln('\n  No Firebase project found (run `flutterfire configure`, or pass --project).');
    return false;
  }
  if (!publisher.isAvailable) {
    out.writeln('\n  Firebase CLI not found, so the parameters are listed below instead.');
    out.writeln('  Install it with `npm i -g firebase-tools`, then `firebase login`.');
    return false;
  }
  try {
    final current = publisher.fetch(projectId);
    final merge = mergeParameters(current, answers.parameters, group: answers.group);
    if (merge.added.isEmpty) {
      out.writeln('\n+ Remote Config in "$projectId" already has every parameter.');
      return true;
    }
    final where = answers.group.isEmpty ? '' : ' (in the folder "${answers.group}")';
    out.writeln('\nRemote Config in "$projectId" will get these new parameters$where:');
    for (final spec in merge.added) {
      out.writeln('  + ${spec.name} = ${spec.example.isEmpty ? '(empty)' : spec.example}');
    }
    if (merge.existing.isNotEmpty) {
      out.writeln('  (already there, left as they are: ${merge.existing.join(', ')})');
    }
    if (!alwaysYes &&
        !ask.confirm('Publish these to Firebase now?', defaultValue: true)) {
      return false;
    }
    publisher.publish(projectId, merge.template, basedOn: current);
    final after = mergeParameters(
      publisher.fetch(projectId),
      answers.parameters,
      group: answers.group,
    );
    if (after.added.isNotEmpty) {
      out.writeln('! Published, but ${after.added.map((s) => s.name).join(', ')} still missing.');
      return false;
    }
    out.writeln('+ Published ${merge.added.length} parameter(s) to "$projectId".');
    return true;
  } on PublishException catch (e) {
    out.writeln('! ${e.message}');
    return false;
  }
}

enum _Kind { gate, firebase }

class _Edit {
  _Edit(this.kind, this.path, this.result);
  final _Kind kind;
  final String path;
  final PatchResult result;
}

/// Works out the edits to `main.dart` and the app widget, without writing.
List<_Edit> _planEdits(
  Directory project,
  SetupAnswers a,
  String appName,
  String importPath,
) {
  final texts = <String, String>{};
  String read(String path) => texts[path] ??= File('${project.path}/$path').readAsStringSync();
  final edits = <_Edit>[];
  /// `package:` style, or relative when the file already imports that way
  /// (many projects forbid `package:` imports for their own code).
  String localImport(String from, String to, String packagePath) =>
      _usesRelativeImports(read(from))
      ? "import '${relativeImport(from, to)}';"
      : "import '$packagePath';";

  final appPath = _findAppFile(project);
  if (appPath != null) {
    final result = wrapAppWithGate(
      read(appPath),
      imports: [
        "import 'package:adaptable_remote_config/adaptable_remote_config.dart';",
        localImport(appPath, a.outputPath, importPath),
      ],
      showOptional: a.usesOptional,
    );
    if (result.changed) texts[appPath] = result.source!;
    edits.add(_Edit(_Kind.gate, appPath, result));
  }

  final initializedIn = _firstFileWith(project, 'Firebase.initializeApp');
  if (a.source == ConfigSource.firebase && initializedIn != null) {
    // Adding a second call would run Firebase setup twice and, in apps that
    // start it late on purpose, put it back on the boot path.
    edits.add(
      _Edit(
        _Kind.firebase,
        initializedIn,
        PatchResult.skipped(
          'Firebase is already initialized in $initializedIn',
          alreadyDone: true,
        ),
      ),
    );
  } else if (a.source == ConfigSource.firebase &&
      File('${project.path}/lib/main.dart').existsSync()) {
    final hasOptions = File('${project.path}/lib/firebase_options.dart').existsSync();
    final result = initFirebaseInMain(
      read('lib/main.dart'),
      imports: [
        "import 'package:firebase_core/firebase_core.dart';",
        if (hasOptions)
          localImport(
            'lib/main.dart',
            'lib/firebase_options.dart',
            'package:$appName/firebase_options.dart',
          ),
      ],
      withOptions: hasOptions,
    );
    if (result.changed) texts['lib/main.dart'] = result.source!;
    edits.add(_Edit(_Kind.firebase, 'lib/main.dart', result));
  }

  // One entry per changed file, carrying its final text.
  return [
    for (final e in edits)
      _Edit(
        e.kind,
        e.path,
        e.result.changed
            ? PatchResult.changed(texts[e.path]!, e.result.note)
            : e.result,
      ),
  ];
}

/// Every Dart file under lib/, as `lib/...` paths with forward slashes.
List<String> _dartFiles(Directory project) {
  final lib = Directory('${project.path}/lib');
  if (!lib.existsSync()) return const [];
  final root = project.path.replaceAll('\\', '/');
  return [
    for (final f in lib.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart'))
        f.path.replaceAll('\\', '/').substring(root.length + 1),
  ];
}

/// The first lib/ file whose text contains [pattern] (ignoring [skip]).
String? _firstFileWith(Directory project, Pattern pattern, {String? skip}) {
  for (final path in _dartFiles(project)) {
    if (path == skip || path.endsWith('.g.dart')) continue;
    if (File('${project.path}/$path').readAsStringSync().contains(pattern)) {
      return path;
    }
  }
  return null;
}

/// True when the file imports its own project's code with relative paths.
bool _usesRelativeImports(String source) =>
    RegExp(r"^import '(?!package:|dart:)", multiLine: true).hasMatch(source);

/// `app_update.dart`, `../core/x.dart`... from file [from] to file [to].
String relativeImport(String from, String to) {
  final fromDirs = from.split('/')..removeLast();
  final toParts = to.split('/');
  var shared = 0;
  while (shared < fromDirs.length &&
      shared < toParts.length - 1 &&
      fromDirs[shared] == toParts[shared]) {
    shared++;
  }
  return [
    for (var i = shared; i < fromDirs.length; i++) '..',
    ...toParts.skip(shared),
  ].join('/');
}

/// The file holding the app widget, preferring main.dart and app.dart.
String? _findAppFile(Directory project) {
  final lib = Directory('${project.path}/lib');
  if (!lib.existsSync()) return null;
  final files = [
    for (final f in lib.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart') &&
          !f.path.endsWith('.g.dart') &&
          !f.path.endsWith('app_update.dart') &&
          hasAppWidget(f.readAsStringSync()))
        f.path.replaceAll('\\', '/').substring(project.path.replaceAll('\\', '/').length + 1),
  ];
  if (files.isEmpty) return null;
  for (final preferred in ['lib/main.dart', 'lib/app.dart', 'lib/src/app.dart']) {
    if (files.contains(preferred)) return preferred;
  }
  return files.first;
}

/// Adds `firebase_core` when Firebase is the source and it is missing.
void _ensureFirebase(
  Prompter ask,
  StringSink out,
  Directory project,
  SetupAnswers a,
  String pubspecText,
  AddDependency add,
) {
  if (a.source != ConfigSource.firebase) return;
  if (RegExp(r'^\s*firebase_core:', multiLine: true).hasMatch(pubspecText)) return;
  if (ask.confirm('Add firebase_core to your app (flutter pub add)?')) {
    out.writeln(
      add(project, 'firebase_core')
          ? '+ added firebase_core'
          : '! could not run `flutter pub add firebase_core`; add it yourself',
    );
  }
  out.writeln('  Run `flutterfire configure` once to connect your Firebase project.');
}

/// `package:my_app/app_update.dart` for a file under lib/.
String _importPath(String appName, String outputPath) {
  final inLib = outputPath.startsWith('lib/')
      ? outputPath.substring('lib/'.length)
      : outputPath;
  return 'package:$appName/$inLib';
}

SetupAnswers _collect(
  Prompter ask,
  String appName,
  String outputPath,
  SetupPreset preset,
) {
  final source = preset.source ??
      ask.select<ConfigSource>('Where do the remote values live?', const [
        Choice(
          'Firebase Remote Config',
          ConfigSource.firebase,
          hint: 'edit them in the Firebase console',
        ),
        Choice(
          'A JSON file / HTTP endpoint',
          ConfigSource.http,
          hint: 'host a file anywhere',
        ),
        Choice(
          'My own code',
          ConfigSource.custom,
          hint: 'any async function that returns a map',
        ),
      ]);

  final mode = preset.mode ??
      ask.select<UpdateMode>('Which updates do you want?', const [
        Choice(
          'Force and optional',
          UpdateMode.both,
          hint: 'blocking wall + dismissible prompt',
        ),
        Choice('Force only', UpdateMode.forceOnly, hint: 'old builds are blocked'),
        Choice(
          'Optional only',
          UpdateMode.optionalOnly,
          hint: 'old builds are asked to update',
        ),
      ]);

  final platforms = ask.multiSelect<String>(
    'Which platforms?',
    const [Choice('Android', 'android'), Choice('iOS', 'ios')],
    initial: {'android', 'ios'},
  );

  final presetPrefix = preset.prefix;
  if (presetPrefix != null && !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(presetPrefix)) {
    throw const SetupAbort('--prefix: use lowercase letters, digits and underscores.');
  }
  final style = presetPrefix != null
      ? KeyStyle.prefixed
      : ask.select<KeyStyle>('How should the keys be named?', [
    const Choice(
      'Standard',
      KeyStyle.standard,
      hint: 'android_version, force_update ...',
    ),
    const Choice(
      'With a prefix',
      KeyStyle.prefixed,
      hint: 'shop_android_version ... (several apps, one project)',
    ),
    if (source != ConfigSource.firebase)
      const Choice(
        'Nested JSON',
        KeyStyle.nested,
        hint: '{"android": {"minimum_version": ...}}',
      ),
  ]);

  var prefix = '';
  if (style == KeyStyle.prefixed) {
    prefix = presetPrefix ?? ask.input(
      'Key prefix',
      defaultValue: appName,
      validate: (v) => RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(v)
          ? null
          : 'Use lowercase letters, digits and underscores.',
    );
  }

  var url = '';
  if (source == ConfigSource.http) {
    url = preset.url ??
        ask.input(
          'URL of the JSON file',
          validate: (v) {
            final uri = Uri.tryParse(v);
            return uri != null && uri.hasScheme && uri.host.isNotEmpty
                ? null
                : 'Enter a full URL, e.g. https://example.com/app.json';
          },
        );
  }

  var group = '';
  if (source == ConfigSource.firebase && !preset.noGroup) {
    group = preset.group ??
        ask.input(
          'Folder in the Firebase console for these keys (Enter for none)',
          defaultValue: style == KeyStyle.prefixed ? prefix : '',
          validate: (v) => RegExp(r'^[A-Za-z0-9_ -]{0,60}$').hasMatch(v)
              ? null
              : 'Use letters, digits, spaces, - and _ (max 60).',
        );
  }

  final appId = ask.input(
    'App id (names the local cache)',
    defaultValue: appName,
    validate: (v) => v.isEmpty ? 'Cannot be empty.' : null,
  );

  final android = platforms.contains('android');
  final ios = platforms.contains('ios');
  return SetupAnswers(
    appId: appId,
    source: source,
    mode: mode,
    android: android,
    ios: ios,
    keyStyle: style,
    prefix: prefix,
    httpUrl: url,
    androidStoreUrl: android
        ? ask.input('Play Store link (Enter: derive from the package name)')
        : '',
    iosStoreUrl: ios ? ask.input('App Store link (needed for iOS updates)') : '',
    outputPath: outputPath,
    group: group,
  );
}
