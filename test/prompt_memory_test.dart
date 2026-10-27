import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart' as helpers;

/// "The log said DIALOG but the dialog never appeared": the user had chosen
/// Later or Skip on an earlier run. These pin that behavior and its log.
void main() {
  late List<String> lines;
  setUp(() => lines = []);

  RemoteConfigLogger logger() => RemoteConfigLogger(print: lines.add);
  String text() => lines.join('\n');
  Map<String, dynamic> optional() => helpers.remote(force: false, latest: '3');

  RemoteConfigController start(MemoryConfigStorage storage, {DateTime? now}) =>
      helpers.controller(
        () async => optional(),
        storage: storage,
        clock: now == null ? null : () => now,
        log: logger(),
      );

  test('a fresh install shows the dialog and the log says so', () async {
    final c = start(MemoryConfigStorage());
    addTearDown(c.dispose);
    await c.initialize();
    expect(c.shouldPrompt, true);
    expect(text(), contains('=> DIALOG'));
    expect(text(), contains('shown: yes, the dialog will appear'));
  });

  test('Skip is remembered across restarts, and the log says why it is hidden', () async {
    final storage = MemoryConfigStorage();
    final first = start(storage);
    await first.initialize();
    await first.dismissOptional(skipVersion: true);
    first.dispose();

    lines.clear();
    final second = start(storage);
    addTearDown(second.dispose);
    await second.initialize();
    expect(second.update.kind, UpdateKind.optional); // still decided: DIALOG
    expect(second.shouldPrompt, false); // but not shown
    expect(text(), contains('=> DIALOG'));
    expect(text(), contains('shown: NO'));
    expect(text(), contains('"Skip this version" for 3'));
    expect(text(), contains('forgetPromptAnswers()'));
  });

  test('the very first decision after a restart already knows the answers', () async {
    final storage = MemoryConfigStorage();
    final first = start(storage);
    await first.initialize();
    await first.dismissOptional(skipVersion: true);
    first.dispose();

    lines.clear();
    final second = helpers.controller(
      () async => throw StateError('offline'), // only the saved copy decides
      storage: storage,
      log: logger(),
    );
    addTearDown(second.dispose);
    await second.initialize();
    expect(text(), contains('RESTORED from the saved copy'));
    expect(text(), contains('shown: NO'));
  });

  test('Later hides it until the reminder time, then it returns', () async {
    final storage = MemoryConfigStorage();
    final t0 = DateTime(2026, 10, 27, 10);
    final first = start(storage, now: t0);
    await first.initialize();
    await first.dismissOptional();
    first.dispose();

    lines.clear();
    final soon = start(storage, now: t0.add(const Duration(hours: 2)));
    addTearDown(soon.dispose);
    await soon.initialize();
    expect(soon.shouldPrompt, false);
    expect(text(), contains('"Later"'));
    expect(text(), contains('shown: NO'));

    final next = start(storage, now: t0.add(const Duration(hours: 25)));
    addTearDown(next.dispose);
    await next.initialize();
    expect(next.shouldPrompt, true);
  });

  test('a newer latest version is offered again even after Skip', () async {
    final storage = MemoryConfigStorage();
    final first = start(storage);
    await first.initialize();
    await first.dismissOptional(skipVersion: true);
    first.dispose();

    final newer = helpers.controller(
      () async => helpers.remote(force: false, latest: '4'),
      storage: storage,
    );
    addTearDown(newer.dispose);
    await newer.initialize();
    expect(newer.update.version, '4');
    expect(newer.shouldPrompt, true);
  });

  test('forgetPromptAnswers brings the dialog back, and it is saved', () async {
    final storage = MemoryConfigStorage();
    final first = start(storage);
    await first.initialize();
    await first.dismissOptional(skipVersion: true);
    expect(first.shouldPrompt, false);
    await first.forgetPromptAnswers();
    expect(first.shouldPrompt, true);
    first.dispose();

    final second = start(storage);
    addTearDown(second.dispose);
    await second.initialize();
    expect(second.shouldPrompt, true); // still forgotten after a restart
  });

  test('a wall has no "shown" line: it can never be hidden', () async {
    final c = helpers.controller(() async => helpers.remote(), log: logger());
    addTearDown(c.dispose);
    await c.initialize();
    expect(text(), contains('=> WALL'));
    expect(text(), isNot(contains('shown:')));
  });
}
