import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart' as helpers;

Widget app(RemoteConfigController c, {GlobalKey<NavigatorState>? key}) =>
    MaterialApp(
      navigatorKey: key,
      builder: (_, child) => UpdateGate(controller: c, child: child!),
      home: const Scaffold(body: Text('Protected home')),
    );

void main() {
  testWidgets('shows a spinner, then the app when no update applies', (
    tester,
  ) async {
    final c = helpers.controller(() async => helpers.remote(minimum: '1'));
    addTearDown(c.dispose);
    await tester.pumpWidget(app(c));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Protected home'), findsOneWidget);
  });

  testWidgets('required update hides the app, deep links and back', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final c = helpers.controller(
      () async => helpers.remote(),
      openStore: (_) async => false,
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(app(c, key: navigator));
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Protected home'), findsNothing);

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Deep link')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deep link'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not open the update. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('requiredBuilder replaces the default page', (tester) async {
    final c = helpers.controller(() async => helpers.remote());
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => UpdateGate(
          controller: c,
          requiredBuilder: (_, controller) => Material(
            child: TextButton(
              onPressed: controller.openUpdate,
              child: const Text('Custom wall'),
            ),
          ),
          child: child!,
        ),
        home: const Text('Protected'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Custom wall'), findsOneWidget);
    expect(find.text('Update required'), findsNothing);
  });

  testWidgets('optional dialog: Later closes it and it stays closed', (
    tester,
  ) async {
    final c = helpers.controller(
      () async => helpers.remote(force: false, latest: '3'),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    expect(find.byType(OptionalUpdateDialog), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.byType(OptionalUpdateDialog), findsNothing);
    expect(find.text('Protected home'), findsOneWidget);
    c.check();
    await tester.pumpAndSettle();
    expect(find.byType(OptionalUpdateDialog), findsNothing);
  });

  testWidgets('showOptional: false never shows the dialog', (tester) async {
    final c = helpers.controller(
      () async => helpers.remote(force: false, latest: '3'),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            UpdateGate(controller: c, showOptional: false, child: child!),
        home: const Text('Protected'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OptionalUpdateDialog), findsNothing);
    expect(find.text('Protected'), findsOneWidget);
  });

  testWidgets('Arabic texts render in RTL on a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = helpers.controller(
      () async => helpers.remote(force: false, latest: '3'),
    );
    addTearDown(c.dispose);
    await c.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: OptionalUpdateDialog(
              controller: c,
              texts: const UpdateTexts.arabic(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('تخطي هذا الإصدار'));
    await tester.pumpAndSettle();
    expect(c.shouldPrompt, false);
  });
}
