import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart' as helpers;

void main() {
  defaultKeyLogTests();
  group('logger', () {
    late List<String> lines;
    setUp(() => lines = []);

    RemoteConfigLogger logger({
      bool values = true,
      bool decision = true,
      bool errors = true,
      bool actions = true,
      Set<String> hide = const {},
      int max = 120,
    }) => RemoteConfigLogger(
      values: values,
      decision: decision,
      errors: errors,
      actions: actions,
      hideKeys: hide,
      maxValueLength: max,
      print: lines.add,
    );

    String text() => lines.join('\n');

    test('prints the fetched keys, sorted and aligned, then the decision', () async {
      final c = helpers.controller(
        () async => helpers.remote(force: false, latest: '3'),
        log: logger(),
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(text(), contains('FETCHED  CustomConfigProvider'));
      expect(text(), contains('android_latest_version = "3"'));
      expect(text(), contains('force_update           = "false"'));
      expect(
        text().indexOf('android_latest_version'),
        lessThan(text().indexOf('base_url')),
      );
      expect(text(), contains('DECISION  (android, installed 1+1)'));
      expect(text(), contains('latest   3   <- android_latest_version'));
      expect(text(), contains('=> DIALOG  (latest 3)'));
    });

    test('says WALL for a required update and NOTHING when up to date', () async {
      final wall = helpers.controller(
        () async => helpers.remote(),
        log: logger(),
      );
      addTearDown(wall.dispose);
      await wall.initialize();
      expect(text(), contains('=> WALL  (minimum 2)'));

      lines.clear();
      final none = helpers.controller(
        () async => helpers.remote(minimum: '1'),
        log: logger(),
      );
      addTearDown(none.dispose);
      await none.initialize();
      expect(text(), contains('=> NOTHING'));
    });

    test('secrets are hidden and long values are cut', () async {
      final c = helpers.controller(
        () async => {
          ...helpers.remote(minimum: '1'),
          'payment_api_key': 'sk_live_123',
          'auth_token': 'abc',
          'my_private': 'hide-me',
          'welcome': 'x' * 300,
        },
        log: logger(hide: {'my_private'}, max: 20),
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(text(), isNot(contains('sk_live_123')));
      expect(text(), isNot(contains('abc')));
      expect(text(), isNot(contains('hide-me')));
      expect(text(), matches(RegExp(r'payment_api_key\s+= "\*\*\*"')));
      expect(text(), contains('(302 chars)'));
    });

    test('a mistake is reported as IGNORED, other errors as ERROR', () async {
      var next = helpers.remote(minimum: '1');
      final c = helpers.controller(() async => next, log: logger());
      addTearDown(c.dispose);
      await c.initialize();
      lines.clear();
      next = helpers.remote(minimum: 'oops');
      await c.refresh();
      expect(text(), contains('IGNORED'));
      expect(text(), contains('FormatException'));

      lines.clear();
      final broken = helpers.controller(
        () async => throw StateError('offline'),
        log: logger(),
      );
      addTearDown(broken.dispose);
      await broken.initialize();
      expect(text(), contains('ERROR'));
      expect(text(), contains('offline'));
    });

    test('each part can be switched off, and no logger means silence', () async {
      final quiet = helpers.controller(
        () async => helpers.remote(),
        log: logger(values: false, decision: false, errors: false, actions: false),
      );
      addTearDown(quiet.dispose);
      await quiet.initialize();
      expect(lines, isEmpty);

      final off = helpers.controller(() async => helpers.remote());
      addTearDown(off.dispose);
      await off.initialize(); // must not throw or print
    });

    test('logs the saved copy and the user taps', () async {
      final storage = MemoryConfigStorage();
      final first = helpers.controller(
        () async => helpers.remote(force: false, latest: '3'),
        storage: storage,
      );
      await first.initialize();
      first.dispose();

      final c = helpers.controller(
        () async => throw StateError('offline'),
        storage: storage,
        log: logger(),
        openStore: (_) async => true,
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(text(), contains('RESTORED from the saved copy'));
      await c.dismissOptional(skipVersion: true);
      await c.openUpdate();
      expect(text(), contains('User tapped "Skip this version" (3)'));
      expect(text(), contains('User tapped "Update"'));
    });
  });

  group('inAppUpdate hook', () {
    test('runs first; when it handles the update the store page is not opened', () async {
      var storeOpened = false;
      final c = helpers.controller(
        () async => helpers.remote(),
        inAppUpdate: (_) async => true,
        openStore: (_) async {
          storeOpened = true;
          return true;
        },
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(await c.openUpdate(), true);
      expect(storeOpened, false);
    });

    test('falls back to the store page when it returns false or throws', () async {
      for (final hook in <Future<bool> Function(UpdateResult)>[
        (_) async => false,
        (_) async => throw StateError('not from Google Play'),
      ]) {
        var storeOpened = false;
        final c = helpers.controller(
          () async => helpers.remote(),
          inAppUpdate: hook,
          openStore: (_) async {
            storeOpened = true;
            return true;
          },
        );
        await c.initialize();
        expect(await c.openUpdate(), true);
        expect(storeOpened, true);
        expect(c.actionError, isNull);
        c.dispose();
      }
    });

    test('it receives the current decision and is not cut off by the timeout', () async {
      UpdateResult? seen;
      final c = helpers.controller(
        () async => helpers.remote(),
        timeout: const Duration(milliseconds: 50),
        inAppUpdate: (result) async {
          seen = result;
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return true;
        },
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(await c.openUpdate(), true);
      expect(seen?.isRequired, true);
      expect(c.actionError, isNull);
    });

    test('a failing store fallback still reports the error', () async {
      final c = helpers.controller(
        () async => helpers.remote(),
        inAppUpdate: (_) async => false,
        openStore: (_) async => false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(await c.openUpdate(), false);
      expect(c.actionError, isNotNull);
    });
  });
}

class _DefaultsProvider extends CustomConfigProvider {
  _DefaultsProvider(super.loader);

  @override
  Set<String> get defaultKeys => const {'android_version'};
}

void defaultKeyLogTests() {
  test('FETCHED marks a key that comes from the app defaults', () async {
    final lines = <String>[];
    final c = RemoteConfigController(
      provider: _DefaultsProvider(
        () async => {'android_version': '1', 'customer_android_version': '2'},
      ),
      appId: 'test',
      storage: MemoryConfigStorage(),
      appInfo: () async => const AppInfo(version: '1+1', packageName: 'a.b'),
      platform: 'android',
      log: RemoteConfigLogger(print: lines.add),
    );
    addTearDown(c.dispose);
    await c.initialize();
    final text = lines.join('\n');
    expect(text, contains('2 keys, 1 of them are defaults'));
    expect(text, contains('android_version          = "1"  (default, not on the server)'));
    expect(text, isNot(contains('"2"  (default')));
  });
}
