import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:adaptable_remote_config_example/main.dart';
import 'package:adaptable_remote_config_example/playground_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boots the playground with its own state so a test can drive it.
Future<PlaygroundState> _boot(WidgetTester tester) async {
  final state = PlaygroundState(toastFor: const Duration(milliseconds: 1));
  addTearDown(state.dispose);
  await tester.pumpWidget(PlaygroundApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('starts up to date: the app is visible, no update screen', (
    tester,
  ) async {
    await _boot(tester);
    expect(find.text('Welcome to the demo app'), findsOneWidget);
    expect(find.text('Update required'), findsNothing);
    expect(find.text('Update available'), findsNothing);
    expect(find.text('Playground · NOTHING'), findsOneWidget);
  });

  testWidgets('"Force update" shows the wall and the pill still works', (
    tester,
  ) async {
    final state = await _boot(tester);
    await state.applyPreset(Preset.force);
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Playground · WALL'), findsOneWidget);
    // The playground is above the gate, so it can still be opened.
    await tester.tap(find.text('Playground · WALL'));
    await tester.pumpAndSettle();
    expect(find.text('Try a case'), findsOneWidget);
  });

  testWidgets('"Optional update" shows the dialog; Later hides it', (
    tester,
  ) async {
    final state = await _boot(tester);
    await state.applyPreset(Preset.optional);
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);
    expect(state.controller.update.kind, UpdateKind.optional);
    expect(state.controller.shouldPrompt, false);
  });

  testWidgets('a mistake in the values is ignored, not shown', (tester) async {
    final state = await _boot(tester);
    await state.applyPreset(Preset.optional);
    await tester.pumpAndSettle();
    await state.applyPreset(Preset.mistake);
    await tester.pumpAndSettle();
    // Minimum above latest is rejected: the dialog from before stays.
    expect(state.controller.update.kind, UpdateKind.optional);
    expect(state.verdict, contains('ignored'));
    expect(find.text('Update required'), findsNothing);
  });

  testWidgets('an iPhone without a store link cannot show the update', (
    tester,
  ) async {
    final state = await _boot(tester);
    await state.applyPreset(Preset.iosNoLink);
    await tester.pumpAndSettle();
    expect(state.platform, 'ios');
    expect(find.text('Update required'), findsNothing);
    expect(state.controller.error, isA<FormatException>());
  });

  testWidgets('Arabic texts and a forced right-to-left direction', (
    tester,
  ) async {
    final state = await _boot(tester);
    state
      ..arabic = true
      ..direction = DirectionMode.rtl
      ..changed();
    await state.applyPreset(Preset.force);
    await tester.pumpAndSettle();
    expect(find.text('التحديث مطلوب'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('التحديث مطلوب'))),
      TextDirection.rtl,
    );
  });

  testWidgets('every card style and icon style draws without errors', (
    tester,
  ) async {
    final state = await _boot(tester);
    for (final card in CardStyle.values) {
      for (final icon in IconStyle.values) {
        state
          ..card = card
          ..icon = icon
          ..changed();
        await state.applyPreset(Preset.optional);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$card + $icon');
        await state.applyPreset(Preset.force);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$card + $icon (wall)');
        await state.applyPreset(Preset.upToDate);
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('the store button: fails (Retry), then opens', (tester) async {
    final state = await _boot(tester);
    await state.applyPreset(Preset.force);
    await tester.pumpAndSettle();

    state
      ..storeOpens = false
      ..changed();
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text('Could not open the update. Please try again.'),
      findsOneWidget,
    );

    state
      ..storeOpens = true
      ..changed();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('the logs tab shows what was fetched and decided', (
    tester,
  ) async {
    final state = await _boot(tester);
    await state.applyPreset(Preset.force);
    await tester.pumpAndSettle();
    expect(state.logs.any((b) => b.title.startsWith('FETCHED')), true);
    expect(state.logs.any((b) => b.title.startsWith('DECISION')), true);
    await tester.tap(find.text('Playground · WALL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logs'));
    await tester.pumpAndSettle();
    expect(find.textContaining('=> WALL'), findsWidgets);
  });

  testWidgets('offline keeps the saved values; a JSON file source works', (
    tester,
  ) async {
    final state = await _boot(tester);
    await state.applyPreset(Preset.force);
    await tester.pumpAndSettle(); // let the pushed fetch finish first
    state
      ..offline = true
      ..changed();
    await state.fetchNow();
    await tester.pumpAndSettle();
    expect(state.controller.update.kind, UpdateKind.required);
    expect(state.logs.any((b) => b.title.startsWith('ERROR')), true);

    state.offline = false;
    state.setSource(SourceKind.http);
    await tester.pumpAndSettle();
    await state.applyPreset(Preset.optional);
    await tester.pumpAndSettle();
    expect(state.controller.update.kind, UpdateKind.optional);
  });
}
