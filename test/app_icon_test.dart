import 'dart:convert';

import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart' as helpers;

/// A 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

Future<RemoteConfigController> _controller({bool force = false}) async {
  final c = helpers.controller(
    () async => force ? helpers.remote() : helpers.remote(force: false, latest: '3'),
  );
  await c.initialize();
  addTearDown(c.dispose);
  return c;
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('shows your app icon instead of the update icon', (tester) async {
    final c = await _controller();
    await tester.pumpWidget(
      _app(OptionalUpdateDialog(controller: c, appIcon: MemoryImage(_png))),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.system_update), findsNothing);
  });

  testWidgets('the wall shows it too, larger than in the dialog', (tester) async {
    final c = await _controller(force: true);
    await tester.pumpWidget(
      _app(RequiredUpdatePage(controller: c, appIcon: MemoryImage(_png))),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.getSize(find.byType(Image)), const Size(96, 96));

    final d = await _controller();
    await tester.pumpWidget(
      _app(OptionalUpdateDialog(controller: d, appIcon: MemoryImage(_png))),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(Image)), const Size(64, 64));
  });

  testWidgets('a missing file falls back to the update icon, no error', (
    tester,
  ) async {
    final c = await _controller();
    // The default path assets/app_icon.png does not exist in this test bundle.
    await tester.pumpWidget(_app(OptionalUpdateDialog(controller: c)));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.system_update), findsOneWidget);
    // No white frame around the fallback icon.
    expect(find.byType(ClipRRect), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the default path is assets/app_icon.png and can be changed', (
    tester,
  ) async {
    expect(defaultAppIconAsset, 'assets/app_icon.png');
    String assetOf(WidgetTester t) =>
        (t.widget<Image>(find.byType(Image)).image as AssetImage).assetName;

    final c = await _controller();
    await tester.pumpWidget(_app(OptionalUpdateDialog(controller: c)));
    expect(assetOf(tester), 'assets/app_icon.png');

    await tester.pumpWidget(
      _app(
        OptionalUpdateDialog(
          controller: c,
          appIcon: const AssetImage('assets/images/logo.png'),
        ),
      ),
    );
    expect(assetOf(tester), 'assets/images/logo.png');
  });

  testWidgets('showAppIcon: false never loads the image', (tester) async {
    final c = await _controller();
    await tester.pumpWidget(
      _app(
        OptionalUpdateDialog(
          controller: c,
          appIcon: MemoryImage(_png),
          showAppIcon: false,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.system_update), findsOneWidget);
  });

  testWidgets('UpdateGate passes the icon to the wall', (tester) async {
    final c = await _controller(force: true);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => UpdateGate(
          controller: c,
          appIcon: MemoryImage(_png),
          child: child!,
        ),
        home: const Text('home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
