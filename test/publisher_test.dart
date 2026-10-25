import 'dart:convert';
import 'dart:io';

import 'package:adaptable_remote_config/src/cli/answers.dart';
import 'package:adaptable_remote_config/src/cli/remote_config_publisher.dart';
import 'package:adaptable_remote_config/src/cli/setup.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behaves like `firebase`: serves a template, accepts a deploy.
class FakeFirebase {
  FakeFirebase(this.live, {this.installed = true});

  Map<String, dynamic> live;
  final bool installed;
  final calls = <List<String>>[];
  void Function(int getNumber)? onGet;
  var _gets = 0;

  ProcessResult call(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) {
    calls.add(args);
    if (!installed) throw ProcessException(executable, args);
    ProcessResult ok([String out = '']) => ProcessResult(0, 0, out, '');
    switch (args.first) {
      case '--version':
        return ok('15.5.1');
      case 'remoteconfig:get':
        onGet?.call(++_gets);
        File(args.last).writeAsStringSync(jsonEncode(live));
        return ok();
      case 'deploy':
        final file = File('$workingDirectory/remoteconfig.template.json');
        live = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        return ok();
    }
    return ProcessResult(0, 1, '', 'unexpected: $args');
  }

  bool get deployed => calls.any((c) => c.first == 'deploy');
}

Map<String, dynamic> _liveTemplate() => {
  'parameters': {
    'base_url': {
      'defaultValue': {'value': 'https://api.example'},
      'valueType': 'STRING',
    },
  },
  'parameterGroups': {
    'client': {
      'parameters': {
        'android_version': {
          'defaultValue': {'value': '2.0.0+7'},
          'valueType': 'STRING',
        },
        'force_update': {
          'defaultValue': {'value': 'true'},
          'valueType': 'BOOLEAN',
        },
      },
    },
  },
};

Set<String> _names(Map<String, dynamic> template) => {
  ...(template['parameters'] as Map<String, dynamic>).keys,
  for (final g in (template['parameterGroups'] as Map<String, dynamic>).values)
    ...((g as Map<String, dynamic>)['parameters'] as Map<String, dynamic>).keys,
};

void main() {
  group('mergeParameters', () {
    const wanted = SetupAnswers(
      appId: 'a',
      source: ConfigSource.firebase,
      mode: UpdateMode.both,
      android: true,
      ios: false,
    );

    test('adds only what is missing and never changes existing values', () {
      final merge = mergeParameters(_liveTemplate(), wanted.parameters);
      expect(merge.existing, ['android_version', 'force_update']);
      expect(merge.added.map((p) => p.name), [
        'android_latest_version',
        'android_store_link',
      ]);
      final groups = merge.template['parameterGroups'] as Map<String, dynamic>;
      expect(jsonEncode(groups), jsonEncode(_liveTemplate()['parameterGroups']));
      final top = merge.template['parameters'] as Map<String, dynamic>;
      expect(top['android_latest_version'], {
        'defaultValue': {'value': '1.0.0+1'},
        'valueType': 'STRING',
      });
      expect((top['base_url'] as Map)['defaultValue'], {'value': 'https://api.example'});
    });

    test('Boolean parameters get the BOOLEAN type', () {
      final merge = mergeParameters(
        {'parameters': <String, dynamic>{}},
        wanted.parameters,
      );
      final top = merge.template['parameters'] as Map<String, dynamic>;
      expect((top['force_update'] as Map)['valueType'], 'BOOLEAN');
      expect((top['android_version'] as Map)['valueType'], 'STRING');
    });

    test('an empty template works and the input is not mutated', () {
      final original = <String, dynamic>{};
      mergeParameters(original, wanted.parameters);
      expect(original, isEmpty);
    });
  });

  group('wizard publishing', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('arc_pub_');
      File('${dir.path}/pubspec.yaml').writeAsStringSync(
        'name: shop\ndependencies:\n  firebase_core: ^3.0.0\n',
      );
      File('${dir.path}/lib/firebase_options.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync("static const o = FirebaseOptions(projectId: 'demo');");
    });
    tearDown(() => dir.deleteSync(recursive: true));

    int run(List<String> flags, FakeFirebase fake, StringBuffer out) => runCli(
      ['--yes', '--dir', dir.path, ...flags],
      out: out,
      publisher: RemoteConfigPublisher(run: fake.call),
    );

    test('--publish adds the parameters and verifies them', () {
      final fake = FakeFirebase(_liveTemplate());
      final out = StringBuffer();
      expect(run(['--publish'], fake, out), 0, reason: out.toString());
      expect(_names(fake.live), containsAll(['ios_version', 'ios_latest_version']));
      expect(
        ((fake.live['parameterGroups'] as Map)['client'] as Map)['parameters'],
        (_liveTemplate()['parameterGroups'] as Map)['client']['parameters'],
      );
      expect(out.toString(), contains('Published'));
      expect(out.toString(), contains('left as they are: android_version, force_update'));
      expect(out.toString(), isNot(contains('Add parameter')));
    });

    test('without --publish a --yes run never writes to Firebase', () {
      final fake = FakeFirebase(_liveTemplate());
      final out = StringBuffer();
      expect(run([], fake, out), 0);
      expect(fake.deployed, false);
      expect(fake.calls, isEmpty);
      expect(out.toString(), contains('Add parameter'));
    });

    test('--no-publish prints the guide even with a CLI present', () {
      final fake = FakeFirebase(_liveTemplate());
      final out = StringBuffer();
      run(['--no-publish'], fake, out);
      expect(fake.calls, isEmpty);
      expect(out.toString(), contains('Add parameter'));
    });

    test('nothing to do when every parameter exists', () {
      final fake = FakeFirebase({
        'parameters': {
          for (final p in const SetupAnswers(
            appId: 'a',
            source: ConfigSource.firebase,
            mode: UpdateMode.both,
            android: true,
            ios: true,
          ).parameters)
            p.name: {'defaultValue': {'value': 'x'}, 'valueType': 'STRING'},
        },
      });
      final out = StringBuffer();
      run(['--publish'], fake, out);
      expect(fake.deployed, false);
      expect(out.toString(), contains('already has every parameter'));
    });

    test('refuses to publish when the console changed mid-run', () {
      final fake = FakeFirebase(_liveTemplate());
      fake.onGet = (n) {
        if (n == 2) {
          (fake.live['parameters'] as Map<String, dynamic>)['someone_elses'] = {
            'defaultValue': {'value': '1'},
            'valueType': 'STRING',
          };
        }
      };
      final out = StringBuffer();
      run(['--publish'], fake, out);
      expect(fake.deployed, false);
      expect(out.toString(), contains('changed while setting up'));
      expect(out.toString(), contains('Add parameter'));
    });

    test('falls back to the guide when the Firebase CLI is missing', () {
      final fake = FakeFirebase(_liveTemplate(), installed: false);
      final out = StringBuffer();
      expect(run(['--publish'], fake, out), 0);
      expect(out.toString(), contains('Firebase CLI not found'));
      expect(out.toString(), contains('Add parameter'));
    });

    test('asks the project id from the flag when none is found', () {
      File('${dir.path}/lib/firebase_options.dart').deleteSync();
      final fake = FakeFirebase(_liveTemplate());
      final out = StringBuffer();
      run(['--publish'], fake, out);
      expect(out.toString(), contains('No Firebase project found'));
      expect(fake.calls, isEmpty);
      run(['--publish', '--project', 'flagged'], fake, StringBuffer());
      expect(fake.calls.any((c) => c.contains('flagged')), true);
    });
  });

  test('readFirebaseProjectId reads options and .firebaserc', () {
    final dir = Directory.systemTemp.createTempSync('arc_id_');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(readFirebaseProjectId(dir), isNull);
    File('${dir.path}/.firebaserc')
        .writeAsStringSync('{"projects": {"default": "from-rc"}}');
    expect(readFirebaseProjectId(dir), 'from-rc');
    File('${dir.path}/lib/firebase_options.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync("projectId: 'from-options'");
    expect(readFirebaseProjectId(dir), 'from-options');
  });
}
