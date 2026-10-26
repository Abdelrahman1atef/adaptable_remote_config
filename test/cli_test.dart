import 'dart:convert';
import 'dart:io';

import 'package:adaptable_remote_config/src/cli/answers.dart';
import 'package:adaptable_remote_config/src/cli/generator.dart';
import 'package:adaptable_remote_config/src/cli/patcher.dart';
import 'package:adaptable_remote_config/src/cli/prompter.dart';
import 'package:adaptable_remote_config/src/cli/setup.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers questions from a fixed script, in order.
class ScriptedPrompter implements Prompter {
  ScriptedPrompter(this.answers);

  final List<Object> answers;

  T _next<T>() => answers.removeAt(0) as T;

  @override
  T select<T>(String question, List<Choice<T>> options, {int initial = 0}) =>
      options[_next<int>()].value;

  @override
  List<T> multiSelect<T>(
    String question,
    List<Choice<T>> options, {
    Set<T> initial = const {},
  }) => [for (final i in _next<List<int>>()) options[i].value];

  @override
  String input(
    String question, {
    String defaultValue = '',
    String? Function(String value)? validate,
  }) {
    final value = _next<String>();
    return value.isEmpty ? defaultValue : value;
  }

  @override
  bool confirm(String question, {bool defaultValue = true}) => _next<bool>();
}

SetupAnswers answers({
  ConfigSource source = ConfigSource.firebase,
  UpdateMode mode = UpdateMode.both,
  bool android = true,
  bool ios = true,
  KeyStyle style = KeyStyle.standard,
  String prefix = 'shop',
  String url = 'https://example.com/app.json',
}) => SetupAnswers(
  appId: 'shop',
  source: source,
  mode: mode,
  android: android,
  ios: ios,
  keyStyle: style,
  prefix: prefix,
  httpUrl: url,
  iosStoreUrl: "https://apps.apple.com/app/id1",
);

const _stockMain = '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: const MyHomePage(title: 'Home'),
    );
  }
}
''';

const _imports = ["import 'package:x/app_update.dart';"];

void main() {
  group('patcher', () {
    test('wraps a stock MaterialApp and adds imports', () {
      final result = wrapAppWithGate(
        _stockMain,
        imports: _imports,
        showOptional: true,
      );
      expect(result.changed, true);
      final source = result.source!;
      expect(source, contains('return MaterialApp(\n      builder: (context, child) => UpdateGate('));
      expect(source, contains('controller: AppUpdate.controller,'));
      expect(source, contains("title: 'Flutter Demo',"));
      expect(source, contains("import 'package:x/app_update.dart';"));
      expect(source, isNot(contains('showOptional')));
    });

    test('showOptional false is written, and const is dropped', () {
      final result = wrapAppWithGate(
        'import "a.dart";\nWidget w() => const MaterialApp(home: X());\n',
        imports: _imports,
        showOptional: false,
      );
      final source = result.source!;
      expect(source, contains('showOptional: false,'));
      expect(source, isNot(contains('const MaterialApp')));
      expect(source, contains('MaterialApp(\n'));
    });

    test('leaves router apps, strings and nested builders alone', () {
      final router = wrapAppWithGate(
        "Widget w() => MaterialApp.router(routerConfig: r, title: ')(');",
        imports: _imports,
        showOptional: true,
      );
      expect(router.changed, true);
      expect(router.source, contains('MaterialApp.router(\n'));
      expect(
        wrapAppWithGate(
          'MaterialApp(builder: (c, w) => w, home: X())',
          imports: _imports,
          showOptional: true,
        ).note,
        'the app already has a builder',
      );
      expect(
        wrapAppWithGate(
          'MaterialApp(home: Builder(builder: (c) => X()))',
          imports: _imports,
          showOptional: true,
        ).changed,
        true,
      );
    });

    test('keeps CRLF line endings consistent', () {
      final crlf = _stockMain.replaceAll('\n', '\r\n');
      final result = wrapAppWithGate(crlf, imports: _imports, showOptional: true);
      final source = result.source!;
      expect(source.replaceAll('\r\n', ''), isNot(contains('\n')));
      expect(source, isNot(contains('\r\r')));
      expect(source, contains('MaterialApp(\r\n      builder:'));
      expect(source, isNot(matches(RegExp(r'\r\n[ \t]+\r\n'))));
    });

    test('is idempotent and refuses ambiguous files', () {
      final once = wrapAppWithGate(_stockMain, imports: _imports, showOptional: true);
      final twice = wrapAppWithGate(once.source!, imports: _imports, showOptional: true);
      expect(twice.alreadyDone, true);
      expect(
        wrapAppWithGate(
          'a() => MaterialApp(); b() => MaterialApp();',
          imports: _imports,
          showOptional: true,
        ).changed,
        false,
      );
      expect(
        wrapAppWithGate('class A {}', imports: _imports, showOptional: true).note,
        'no MaterialApp found',
      );
    });

    test('initializes Firebase in main(), with and without options', () {
      final plain = initFirebaseInMain(
        _stockMain,
        imports: const ["import 'package:firebase_core/firebase_core.dart';"],
        withOptions: false,
      ).source!;
      expect(plain, contains('Future<void> main() async {\n  WidgetsFlutterBinding.ensureInitialized();\n  await Firebase.initializeApp();\n  runApp'));
      final withOptions = initFirebaseInMain(
        'import "package:flutter/material.dart";\nvoid main() async {\n  WidgetsFlutterBinding.ensureInitialized();\n  runApp(A());\n}\n',
        imports: const [],
        withOptions: true,
      ).source!;
      expect(
        withOptions,
        contains('ensureInitialized();\n  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);'),
      );
      expect(
        initFirebaseInMain(plain, imports: const [], withOptions: false).alreadyDone,
        true,
      );
      expect(
        initFirebaseInMain('void main() => runApp(A());', imports: const [], withOptions: false).changed,
        false,
      );
    });
  });

  group('parameters', () {
    test('standard keys, force + optional, both platforms', () {
      final names = answers().parameters.map((p) => p.name).toList();
      expect(names, [
        'android_version',
        'force_update',
        'android_latest_version',
        'android_store_link',
        'ios_version',
        'ios_latest_version',
        'ios_store_link',
      ]);
    });

    test('force only drops the latest versions; optional only drops force', () {
      final force = answers(mode: UpdateMode.forceOnly, android: false);
      expect(force.parameters.map((p) => p.name), [
        'ios_version',
        'force_update',
        'ios_store_link',
      ]);
      final soft = answers(mode: UpdateMode.optionalOnly, ios: false);
      expect(soft.parameters.map((p) => p.name), [
        'android_latest_version',
        'android_store_link',
      ]);
    });

    test('prefixed and nested key styles', () {
      final prefixed = answers(style: KeyStyle.prefixed, ios: false);
      expect(prefixed.parameters.first.name, 'shop_android_version');
      expect(prefixed.parameters[1].name, 'shop_force_update');
      final nested = answers(style: KeyStyle.nested, source: ConfigSource.http);
      expect(nested.parameters.first.name, 'android.minimum_version');
    });
  });

  group('appUpdateSource', () {
    test('Firebase lists defaults and listens for changes', () {
      final source = appUpdateSource(answers(ios: false));
      expect(source, contains('FirebaseConfigProvider('));
      expect(source, contains("'android_version': '1.0.0+1',"));
      expect(source, contains("'force_update': false,"));
      expect(source, contains('subscribeToChanges: true'));
      expect(source, isNot(contains('keys:')));
    });

    test('HTTP uses the url and key style', () {
      final source = appUpdateSource(
        answers(source: ConfigSource.http, style: KeyStyle.nested),
      );
      expect(source, contains("HttpConfigProvider(url: Uri.parse('https://example.com/app.json'))"));
      expect(source, contains('keys: const UpdateKeys.nested(),'));
      expect(source, isNot(contains('subscribeToChanges')));
    });

    test('custom has a loader stub and a prefix', () {
      final source = appUpdateSource(
        answers(source: ConfigSource.custom, style: KeyStyle.prefixed),
      );
      expect(source, contains('CustomConfigProvider(() async {'));
      expect(source, contains("UpdateKeys.prefixed('shop')"));
    });

    test('quotes and dollars in values are escaped', () {
      final source = appUpdateSource(
        const SetupAnswers(
          appId: r"it's $x",
          source: ConfigSource.http,
          mode: UpdateMode.both,
          android: true,
          ios: false,
          httpUrl: "https://e.com/a?b='c'",
        ),
      );
      expect(source, contains(r"appId: 'it\'s \$x'"));
    });
  });

  group('guides', () {
    test('Firebase guide lists every parameter with its type', () {
      final guide = remoteValuesGuide(answers(ios: false));
      expect(guide, contains('android_version  [String]'));
      expect(guide, contains('force_update  [Boolean]'));
      expect(guide, contains('Publish changes'));
    });

    test('HTTP guide is valid JSON in the chosen shape', () {
      final guide = remoteValuesGuide(
        answers(source: ConfigSource.http, style: KeyStyle.nested),
      );
      final json = jsonDecode(guide.substring(guide.indexOf('{'))) as Map;
      expect((json['android'] as Map)['force_update'], false);
      expect((json['ios'] as Map)['store_url'], 'https://apps.apple.com/app/id1');
    });

    test('next steps drop showOptional when optional is off', () {
      final steps = nextSteps(
        answers(mode: UpdateMode.forceOnly),
        importPath: 'package:shop/app_update.dart',
      );
      expect(steps, contains('showOptional: false'));
      expect(steps, contains('Firebase.initializeApp()'));
      expect(steps, contains("import 'package:shop/app_update.dart'"));
      expect(
        nextSteps(
          answers(),
          importPath: 'package:shop/app_update.dart',
          firebaseDone: true,
          gateDone: true,
        ),
        isEmpty,
      );
    });
  });

  group('wizard', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('arc_cli_');
      File('${dir.path}/pubspec.yaml').writeAsStringSync(
        'name: shop_app\ndependencies:\n  firebase_core: ^3.0.0\n',
      );
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('writes lib/app_update.dart from the chosen answers', () {
      final out = StringBuffer();
      final code = runSetup(
        ScriptedPrompter([
          0, // Firebase
          1, // force only
          [0], // android
          1, // prefixed
          '', // prefix -> app name
          '', // console folder -> the prefix
          '', // app id -> app name
          '', // play store link
        ]),
        out,
        projectDir: dir,
      );
      expect(code, 0);
      final file = File('${dir.path}/lib/app_update.dart');
      final source = file.readAsStringSync();
      expect(source, contains("appId: 'shop_app'"));
      expect(source, contains("UpdateKeys.prefixed('shop_app')"));
      expect(source, contains("'shop_app_android_version'"));
      expect(out.toString(), contains('package:shop_app/app_update.dart'));
      expect(out.toString(), isNot(contains('add firebase_core')));
    });

    test('asks before overwriting and can keep the old file', () {
      File('${dir.path}/lib/app_update.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('// mine');
      final out = StringBuffer();
      runSetup(
        ScriptedPrompter([0, 0, [0, 1], 0, '', '', '', '', false]),
        out,
        projectDir: dir,
      );
      expect(File('${dir.path}/lib/app_update.dart').readAsStringSync(), '// mine');
      expect(out.toString(), contains('kept your existing'));
    });

    test('refuses to run outside a Flutter project', () {
      final empty = Directory.systemTemp.createTempSync('arc_empty_');
      addTearDown(() => empty.deleteSync(recursive: true));
      final out = StringBuffer();
      expect(runSetup(ScriptedPrompter([]), out, projectDir: empty), 66);
      expect(out.toString(), contains('No pubspec.yaml'));
    });

    test('--yes sets up a stock Flutter app with no questions', () {
      Directory('${dir.path}/lib').createSync();
      File('${dir.path}/lib/main.dart').writeAsStringSync(_stockMain);
      final added = <String>[];
      final out = StringBuffer();
      File('${dir.path}/pubspec.yaml').writeAsStringSync('name: shop_app\n');
      final code = runCli(
        ['--yes', '--dir', dir.path],
        out: out,
        addDependency: (_, package) {
          added.add(package);
          return true;
        },
      );
      expect(code, 0, reason: out.toString());
      final main = File('${dir.path}/lib/main.dart').readAsStringSync();
      expect(main, contains('Future<void> main() async {'));
      expect(main, contains('await Firebase.initializeApp();'));
      expect(main, contains("import 'package:firebase_core/firebase_core.dart';"));
      expect(main, contains('UpdateGate('));
      expect(main, contains("import 'package:shop_app/app_update.dart';"));
      expect(File('${dir.path}/lib/app_update.dart').existsSync(), true);
      expect(added, ['firebase_core']);
      expect(out.toString(), isNot(contains('Still to do by hand')));
    });

    test('stops when the app already creates a RemoteConfigController', () {
      File('${dir.path}/lib/core/config/app_update.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('final c = RemoteConfigController(appId: "x");');
      File('${dir.path}/lib/main.dart').writeAsStringSync(_stockMain);
      final out = StringBuffer();
      expect(runCli(['--yes', '--dir', dir.path], out: out), 0);
      expect(out.toString(), contains('already sets this up'));
      expect(File('${dir.path}/lib/app_update.dart').existsSync(), false);
      expect(File('${dir.path}/lib/main.dart').readAsStringSync(), _stockMain);
    });

    test('does not add a second Firebase.initializeApp', () {
      File('${dir.path}/lib/core/boot.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('Future<void> go() => Firebase.initializeApp();');
      File('${dir.path}/lib/main.dart').writeAsStringSync(_stockMain);
      final out = StringBuffer();
      expect(
        runCli(['--yes', '--dir', dir.path], out: out, addDependency: (_, _) => true),
        0,
      );
      final main = File('${dir.path}/lib/main.dart').readAsStringSync();
      expect(main, isNot(contains('Firebase.initializeApp')));
      expect(main, contains('UpdateGate('));
      expect(out.toString(), isNot(contains('Initialize Firebase')));
    });

    test('uses relative imports when the project does', () {
      File('${dir.path}/lib/src/app.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          "import '../core/theme.dart';\n$_stockMain",
        );
      final out = StringBuffer();
      expect(
        runCli(
          ['--yes', '--dir', dir.path, '--source', 'custom'],
          out: out,
        ),
        0,
      );
      final app = File('${dir.path}/lib/src/app.dart').readAsStringSync();
      expect(app, contains("import '../app_update.dart';"));
      expect(app, isNot(contains('package:shop_app/app_update.dart')));
    });

    test('relative import paths are computed from the importing file', () {
      expect(relativeImport('lib/main.dart', 'lib/app_update.dart'), 'app_update.dart');
      expect(relativeImport('lib/src/app.dart', 'lib/app_update.dart'), '../app_update.dart');
      expect(relativeImport('lib/a/b/c.dart', 'lib/a/x.dart'), '../x.dart');
    });

    test('--yes with http needs a url, and accepts flags', () {
      File('${dir.path}/pubspec.yaml').writeAsStringSync('name: shop_app\n');
      final out = StringBuffer();
      expect(
        runCli(['--yes', '--dir', dir.path, '--source', 'http'], out: out),
        64,
      );
      expect(out.toString(), contains('URL of the JSON file'));
      expect(
        runCli(
          [
            '--yes', '--dir', dir.path, '--source', 'http', '--mode', 'force',
            '--url', 'https://example.com/app.json',
          ],
          out: StringBuffer(),
        ),
        0,
      );
      final source = File('${dir.path}/lib/app_update.dart').readAsStringSync();
      expect(source, contains('https://example.com/app.json'));
      expect(runCli(['--yes', '--mode', 'nope'], out: StringBuffer()), 64);
    });

    test('--help and unknown flags', () {
      final out = StringBuffer();
      expect(runCli(['--help'], out: out), 0);
      expect(out.toString(), contains('Usage:'));
      expect(runCli(['--nope'], out: StringBuffer()), 64);
    });
  });
}
