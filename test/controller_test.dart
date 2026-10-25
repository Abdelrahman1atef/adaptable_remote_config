import 'dart:async';

import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart' as helpers;

void main() {
  test('applies a remote snapshot over the local defaults', () async {
    final c = helpers.controller(() async => helpers.remote());
    addTearDown(c.dispose);
    await c.initialize();
    expect(c.isReady, true);
    expect(c.update.kind, UpdateKind.required);
    expect(c.values.string('base_url'), 'https://api.example');
  });

  test('keeps the defaults and lets the user in when the first fetch fails', () async {
    final errors = <Object>[];
    final c = RemoteConfigController(
      provider: CustomConfigProvider(() async => throw StateError('offline')),
      appId: 'test',
      storage: MemoryConfigStorage(),
      defaults: const {'base_url': 'https://default.example'},
      appInfo: () async => const AppInfo(version: '1', packageName: 'p'),
      platform: 'android',
      onError: (error, _) => errors.add(error),
    );
    addTearDown(c.dispose);
    await c.initialize();
    expect(c.update.kind, UpdateKind.none);
    expect(c.values.string('base_url'), 'https://default.example');
    expect(errors.single, isA<StateError>());
  });

  test('falls back to the cached snapshot when a refresh fails', () async {
    final storage = MemoryConfigStorage();
    final first = helpers.controller(
      () async => helpers.remote(),
      storage: storage,
    );
    await first.initialize();
    first.dispose();

    final second = helpers.controller(
      () async => throw StateError('offline'),
      storage: storage,
    );
    addTearDown(second.dispose);
    await second.initialize();
    expect(second.update.kind, UpdateKind.required);
    expect(second.values.string('base_url'), 'https://api.example');
  });

  test('an invalid snapshot is rejected and the last valid one stays', () async {
    var next = helpers.remote(baseUrl: 'https://good.example');
    final c = helpers.controller(() async => next);
    addTearDown(c.dispose);
    await c.initialize();
    next = helpers.remote(minimum: 'oops', baseUrl: 'https://bad.example');
    await c.refresh();
    expect(c.error, isA<FormatException>());
    expect(c.values.string('base_url'), 'https://good.example');
    expect(c.update.kind, UpdateKind.required);
  });

  test('startup is bounded by startupWait', () async {
    final never = Completer<Map<String, dynamic>>();
    final c = helpers.controller(
      () => never.future,
      timeout: const Duration(milliseconds: 50),
    );
    addTearDown(c.dispose);
    await c.initialize();
    expect(c.isReady, true);
    expect(c.update.kind, UpdateKind.none);
  });

  test('refresh(force: false) skips the call inside refreshInterval', () async {
    var calls = 0;
    final c = helpers.controller(() async {
      calls++;
      return helpers.remote();
    });
    addTearDown(c.dispose);
    await c.initialize();
    await c.refresh(force: false);
    expect(calls, 1);
    await c.refresh();
    expect(calls, 2);
  });

  test('a provider change event triggers a refetch', () async {
    final events = StreamController<void>.broadcast();
    addTearDown(events.close);
    var baseUrl = 'https://one.example';
    final c = helpers.controller(
      () async => helpers.remote(baseUrl: baseUrl),
      changes: events.stream,
    );
    addTearDown(c.dispose);
    await c.initialize();
    baseUrl = 'https://two.example';
    events.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.values.string('base_url'), 'https://two.example');
  });

  group('optional updates', () {
    Map<String, dynamic> optional() => helpers.remote(force: false, latest: '3');

    test('Later hides the prompt until remindAfter, then it returns', () async {
      var now = DateTime(2026);
      final c = helpers.controller(() async => optional(), clock: () => now);
      addTearDown(c.dispose);
      await c.initialize();
      expect(c.shouldPrompt, true);
      await c.dismissOptional();
      expect(c.shouldPrompt, false);
      now = now.add(const Duration(days: 1));
      expect(c.shouldPrompt, true);
    });

    test('Skip hides that version for good and survives a restart', () async {
      final storage = MemoryConfigStorage();
      final first = helpers.controller(() async => optional(), storage: storage);
      await first.initialize();
      await first.dismissOptional(skipVersion: true);
      first.dispose();

      final second = helpers.controller(
        () async => optional(),
        storage: storage,
      );
      addTearDown(second.dispose);
      await second.initialize();
      expect(second.shouldPrompt, false);
      expect(second.update.kind, UpdateKind.optional);
    });

    test('a required update ignores dismissal', () async {
      final c = helpers.controller(() async => helpers.remote());
      addTearDown(c.dispose);
      await c.initialize();
      await c.dismissOptional(skipVersion: true);
      expect(c.update.isRequired, true);
    });
  });

  group('openUpdate', () {
    test('runs the store action and keeps the block', () async {
      UpdateResult? opened;
      final c = helpers.controller(
        () async => helpers.remote(),
        openStore: (result) async {
          opened = result;
          return true;
        },
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(await c.openUpdate(), true);
      expect(opened!.destination.toString(), 'https://example.com/update');
      expect(c.update.isRequired, true);
    });

    test('a failed launch is exposed as actionError', () async {
      final c = helpers.controller(
        () async => helpers.remote(),
        openStore: (_) async => false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(await c.openUpdate(), false);
      expect(c.actionError, isNotNull);
    });
  });

  test('a disposed controller refuses new work', () {
    final c = helpers.controller(() async => helpers.remote());
    c.dispose();
    expect(c.initialize, throwsStateError);
  });
}
