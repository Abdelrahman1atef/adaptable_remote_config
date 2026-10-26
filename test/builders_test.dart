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
    () async =>
        force ? helpers.remote() : helpers.remote(force: false, latest: '3'),
  );
  await c.initialize();
  addTearDown(c.dispose);
  return c;
}

Widget _app(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('appIcon (level 1)', () {
    testWidgets('nothing is shown unless you pass one: no hidden path', (
      tester,
    ) async {
      final c = await _controller();
      await tester.pumpWidget(_app(OptionalUpdateDialog(controller: c)));
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.system_update), findsOneWidget);
    });

    testWidgets('the image you pass is shown instead of the update icon', (
      tester,
    ) async {
      final c = await _controller();
      await tester.pumpWidget(
        _app(OptionalUpdateDialog(controller: c, appIcon: MemoryImage(_png))),
      );
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.system_update), findsNothing);
    });

    testWidgets('it is larger on the wall than on the dialog', (tester) async {
      final wall = await _controller(force: true);
      await tester.pumpWidget(
        _app(RequiredUpdatePage(controller: wall, appIcon: MemoryImage(_png))),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(Image)), const Size(96, 96));

      final dialog = await _controller();
      await tester.pumpWidget(
        _app(
          OptionalUpdateDialog(controller: dialog, appIcon: MemoryImage(_png)),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(Image)), const Size(64, 64));
    });

    testWidgets('a broken image falls back to the round icon, quietly', (
      tester,
    ) async {
      final c = await _controller();
      await tester.pumpWidget(
        _app(
          OptionalUpdateDialog(
            controller: c,
            appIcon: const AssetImage('assets/does_not_exist.png'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.system_update), findsOneWidget);
      expect(find.byType(ClipRRect), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('iconBuilder (level 2)', () {
    testWidgets('builds any widget and wins over appIcon', (tester) async {
      final c = await _controller();
      double? size;
      await tester.pumpWidget(
        _app(
          OptionalUpdateDialog(
            controller: c,
            appIcon: MemoryImage(_png),
            iconBuilder: (context, s) {
              size = s;
              return const Text('MY ICON');
            },
          ),
        ),
      );
      expect(find.text('MY ICON'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(size, 64);
    });

    testWidgets('gets 96 on the wall', (tester) async {
      final c = await _controller(force: true);
      double? size;
      await tester.pumpWidget(
        _app(
          RequiredUpdatePage(
            controller: c,
            iconBuilder: (context, s) {
              size = s;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(size, 96);
    });
  });

  group('cardBuilder (level 3)', () {
    testWidgets('lays out the parts you choose, and the buttons still work', (
      tester,
    ) async {
      final c = await _controller();
      UpdateCardData? seen;
      await tester.pumpWidget(
        _app(
          OptionalUpdateDialog(
            controller: c,
            cardBuilder: (context, data) {
              seen = data;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('CUSTOM ${data.title}'),
                  data.icon,
                  Text(data.message),
                  data.updateButton,
                  if (data.laterButton != null) data.laterButton!,
                ],
              );
            },
          ),
        ),
      );
      expect(find.text('CUSTOM Update available'), findsOneWidget);
      expect(find.byType(UpdateCard), findsNothing);
      expect(seen!.isRequired, false);
      expect(seen!.update.kind, UpdateKind.optional);
      expect(seen!.skipButton, isNotNull);

      await tester.tap(find.text('Later'));
      await tester.pump();
      expect(c.shouldPrompt, false);
    });

    testWidgets('on the wall there is no Later or Skip', (tester) async {
      final c = await _controller(force: true);
      UpdateCardData? seen;
      await tester.pumpWidget(
        _app(
          RequiredUpdatePage(
            controller: c,
            cardBuilder: (context, data) {
              seen = data;
              return data.updateButton;
            },
          ),
        ),
      );
      expect(seen!.isRequired, true);
      expect(seen!.title, 'Update required');
      expect(seen!.laterButton, isNull);
      expect(seen!.skipButton, isNull);
    });

    testWidgets('allowSkip: false removes the skip part', (tester) async {
      final c = await _controller();
      UpdateCardData? seen;
      await tester.pumpWidget(
        _app(
          OptionalUpdateDialog(
            controller: c,
            allowSkip: false,
            cardBuilder: (context, data) {
              seen = data;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen!.skipButton, isNull);
      expect(seen!.laterButton, isNotNull);
    });

    testWidgets('UpdateCard.fromData lets you wrap the default look', (
      tester,
    ) async {
      final c = await _controller();
      await tester.pumpWidget(
        _app(
          OptionalUpdateDialog(
            controller: c,
            cardBuilder: (context, data) => Banner(
              message: 'NEW',
              location: BannerLocation.topEnd,
              child: UpdateCard.fromData(data),
            ),
          ),
        ),
      );
      expect(find.byType(UpdateCard), findsOneWidget);
      expect(find.text('Update available'), findsOneWidget);
    });
  });

  group('UpdateGate passes everything through', () {
    testWidgets('appIcon, iconBuilder and cardBuilder reach the wall', (
      tester,
    ) async {
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
      expect(find.byType(Image), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => UpdateGate(
            controller: c,
            iconBuilder: (_, _) => const Text('GATE ICON'),
            cardBuilder: (_, data) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [data.icon, Text(data.title), data.updateButton],
            ),
            child: child!,
          ),
          home: const Text('home'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('GATE ICON'), findsOneWidget);
      expect(find.byType(UpdateCard), findsNothing);
    });
  });
}
