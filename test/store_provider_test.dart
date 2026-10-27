import 'dart:convert';

import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The store itself as the source: nothing to edit, the store knows the newest
/// version.
void main() {
  Future<AppInfo> app() async =>
      const AppInfo(version: '1.0.0+1', packageName: 'com.example.app');

  RemoteConfigController controllerFor(
    StoreConfigProvider provider,
    String platform,
  ) => RemoteConfigController(
    provider: provider,
    appId: 'test',
    storage: MemoryConfigStorage(),
    appInfo: app,
    platform: platform,
  );

  http.Client appStore(Map<String, Object?> body, {int status = 200}) =>
      MockClient((request) async {
        expect(request.url.host, 'itunes.apple.com');
        expect(request.url.queryParameters['bundleId'], 'com.example.app');
        return http.Response(jsonEncode(body), status);
      });

  group('iOS (App Store lookup)', () {
    test('a newer store version is an optional update with the store page',
        () async {
      final c = controllerFor(
        StoreConfigProvider(
          platform: 'ios',
          appInfo: app,
          client: appStore({
            'resultCount': 1,
            'results': [
              {'version': '1.2.0', 'trackViewUrl': 'https://apps.apple.com/app/id1'},
            ],
          }),
        ),
        'ios',
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(c.update.kind, UpdateKind.optional);
      expect(c.update.version, '1.2.0');
      expect(c.update.destination.toString(), 'https://apps.apple.com/app/id1');
    });

    test('the same version in the store means nothing to do', () async {
      final c = controllerFor(
        StoreConfigProvider(
          platform: 'ios',
          appInfo: app,
          client: appStore({
            'resultCount': 1,
            'results': [
              {'version': '1.0.0', 'trackViewUrl': 'https://apps.apple.com/app/id1'},
            ],
          }),
        ),
        'ios',
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(c.update.kind, UpdateKind.none);
    });

    test('an app that is not in the store yet shows nothing', () async {
      final provider = StoreConfigProvider(
        platform: 'ios',
        appInfo: app,
        client: appStore({'resultCount': 0, 'results': []}),
      );
      expect((await provider.fetch())['ios_latest_version'], '1.0.0+1');
    });

    test('the country is sent, and a failed lookup throws', () async {
      final provider = StoreConfigProvider(
        platform: 'ios',
        appInfo: app,
        country: 'eg',
        client: MockClient((request) async {
          expect(request.url.queryParameters['country'], 'eg');
          return http.Response('no', 500);
        }),
      );
      await expectLater(provider.fetch(), throwsA(isA<http.ClientException>()));
    });
  });

  group('Android (Google Play)', () {
    test('a newer build on Play is an optional update', () async {
      final c = controllerFor(
        StoreConfigProvider(
          platform: 'android',
          appInfo: app,
          android: () async => const StoreRelease.build(12),
        ),
        'android',
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(c.update.kind, UpdateKind.optional);
      expect(c.update.version, '1.0.0+12');
    });

    test('Play priority force makes it a blocking update', () async {
      final c = controllerFor(
        StoreConfigProvider(
          platform: 'android',
          appInfo: app,
          android: () async => const StoreRelease.build(12, force: true),
        ),
        'android',
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(c.update.kind, UpdateKind.required);
    });

    test('no newer release on Play means nothing to do', () async {
      final c = controllerFor(
        StoreConfigProvider(
          platform: 'android',
          appInfo: app,
          android: () async => null,
        ),
        'android',
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(c.update.kind, UpdateKind.none);
    });

    test('without an Android function nothing is offered', () async {
      final provider = StoreConfigProvider(platform: 'android', appInfo: app);
      expect((await provider.fetch())['android_latest_version'], '1.0.0+1');
    });
  });
}
