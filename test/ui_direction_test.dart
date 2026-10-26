import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart' as helpers;

/// Draws [child] in an app whose reading direction is [direction].
Widget _app(TextDirection direction, Widget child) => MaterialApp(
  builder: (_, app) => Directionality(textDirection: direction, child: app!),
  home: Scaffold(body: Center(child: child)),
);

Future<RemoteConfigController> _controller() async {
  final c = helpers.controller(
    () async => helpers.remote(force: false, latest: '3'),
  );
  await c.initialize();
  addTearDown(c.dispose);
  return c;
}

/// How far from the card's start edge a widget sits (0 = at the start).
double _fromStart(WidgetTester tester, Finder item, TextDirection d) {
  final card = tester.getRect(find.byType(UpdateCard));
  final rect = tester.getRect(item);
  return d == TextDirection.ltr
      ? rect.left - card.left
      : card.right - rect.right;
}

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('dialog content starts at the start edge in $direction', (
      tester,
    ) async {
      final c = await _controller();
      await tester.pumpWidget(
        _app(direction, OptionalUpdateDialog(showAppIcon: false, controller: c)),
      );
      final title = find.text('Update available');
      final icon = find.byIcon(Icons.system_update);
      // Icon and title hug the start edge, whatever side that is.
      expect(_fromStart(tester, icon, direction), lessThan(40));
      expect(_fromStart(tester, title, direction), lessThan(40));
      // ...and the far edge is empty.
      final card = tester.getRect(find.byType(UpdateCard));
      final end = direction == TextDirection.ltr
          ? card.right - tester.getRect(title).right
          : tester.getRect(title).left - card.left;
      expect(end, greaterThan(40));
    });
  }

  testWidgets('Arabic texts are right-to-left even in a left-to-right app', (
    tester,
  ) async {
    final c = await _controller();
    await tester.pumpWidget(
      _app(
        TextDirection.ltr,
        OptionalUpdateDialog(showAppIcon: false, controller: c, texts: const UpdateTexts.arabic()),
      ),
    );
    final title = find.text('يتوفر تحديث');
    expect(Directionality.of(tester.element(title)), TextDirection.rtl);
    expect(_fromStart(tester, title, TextDirection.rtl), lessThan(40));
    expect(
      _fromStart(tester, find.byIcon(Icons.system_update), TextDirection.rtl),
      lessThan(40),
    );
  });

  testWidgets('English texts follow the app direction unless overridden', (
    tester,
  ) async {
    final c = await _controller();
    await tester.pumpWidget(
      _app(TextDirection.rtl, OptionalUpdateDialog(showAppIcon: false, controller: c)),
    );
    expect(
      Directionality.of(tester.element(find.text('Update available'))),
      TextDirection.rtl,
    );

    await tester.pumpWidget(
      _app(
        TextDirection.rtl,
        OptionalUpdateDialog(showAppIcon: false, controller: c,
          texts: const UpdateTexts(textDirection: TextDirection.ltr),
        ),
      ),
    );
    expect(
      Directionality.of(tester.element(find.text('Update available'))),
      TextDirection.ltr,
    );
  });

  for (final direction in TextDirection.values) {
    testWidgets('the wall is centered in $direction', (tester) async {
      final c = helpers.controller(() async => helpers.remote());
      await c.initialize();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _app(direction, RequiredUpdatePage(showAppIcon: false, controller: c)),
      );
      final screen = tester.getCenter(find.byType(RequiredUpdatePage));
      expect(
        tester.getCenter(find.text('Update required')).dx,
        closeTo(screen.dx, 1),
      );
      expect(
        tester.getCenter(find.byIcon(Icons.system_update)).dx,
        closeTo(screen.dx, 1),
      );
    });
  }

  for (final direction in TextDirection.values) {
    testWidgets('no overflow on a narrow screen with big text in $direction', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await _controller();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(280, 600),
            textScaler: TextScaler.linear(2),
          ),
          child: _app(
            direction,
            OptionalUpdateDialog(showAppIcon: false, controller: c,
              texts: const UpdateTexts.arabic(),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the card follows the theme (dark scheme)', (tester) async {
    final c = await _controller();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
        ),
        home: Scaffold(body: Center(child: OptionalUpdateDialog(showAppIcon: false, controller: c))),
      ),
    );
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(UpdateCard),
        matching: find.byType(Material),
      ).first,
    );
    expect(material.color, isNot(Colors.white));
  });
}
