import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart' as helpers;

const app = AppInfo(version: '1.2.0+4', packageName: 'com.example.app');

UpdateResult decide(
  Map<String, dynamic> values, {
  String? platform = 'android',
  UpdateKeys keys = const UpdateKeys(),
}) => evaluateUpdate(
  values: RemoteValues(values),
  keys: keys,
  app: app,
  platform: platform,
);

void main() {
  group('compareVersions', () {
    test('pads missing parts and breaks ties with the build', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2.0+4', '1.2.0+5'), lessThan(0));
      expect(compareVersions('1.10', '1.9'), greaterThan(0));
      expect(compareVersions('1.2.0', '1.2.0+1'), lessThan(0));
    });

    test('throws on malformed input', () {
      expect(() => compareVersions('1.x', '1'), throwsFormatException);
      expect(() => compareVersions('1', ''), throwsFormatException);
    });
  });

  group('evaluateUpdate', () {
    test('required when forced and below the minimum', () {
      final result = decide(helpers.remote(minimum: '2.0.0'));
      expect(result.kind, UpdateKind.required);
      expect(result.version, '2.0.0');
    });

    test('not required when forcing is off, optional below latest', () {
      final result = decide(
        helpers.remote(minimum: '2.0.0', latest: '3.0.0', force: false),
      );
      expect(result.kind, UpdateKind.optional);
      expect(result.version, '3.0.0');
    });

    test('none when current, with no keys, or on an unsupported platform', () {
      expect(decide(helpers.remote(minimum: '1.2.0+4')).kind, UpdateKind.none);
      expect(decide(const {}).kind, UpdateKind.none);
      expect(decide(helpers.remote(), platform: null).kind, UpdateKind.none);
    });

    test('derives the Play Store link on Android only', () {
      final values = helpers.remote()
        ..remove('android_store_link')
        ..remove('ios_store_link');
      expect(
        decide(values).destination.toString(),
        'https://play.google.com/store/apps/details?id=com.example.app',
      );
      expect(() => decide(values, platform: 'ios'), throwsFormatException);
    });

    test('rejects bad versions, latest below minimum and bad links', () {
      expect(() => decide(helpers.remote(minimum: 'x')), throwsFormatException);
      expect(
        () => decide(helpers.remote(minimum: '3', latest: '2')),
        throwsFormatException,
      );
      expect(
        () => decide(helpers.remote(url: 'javascript:alert(1)')),
        throwsFormatException,
      );
    });

    test('keys can be prefixed, nested or any custom template', () {
      expect(
        decide(
          {
            'shop_android_version': '2',
            'shop_force_update': 'true',
            'shop_android_store_link': 'market://details?id=com.example.app',
          },
          keys: const UpdateKeys.prefixed('shop'),
        ).kind,
        UpdateKind.required,
      );
      expect(
        decide(
          {
            'android': {
              'minimum_version': '2',
              'force_update': true,
              'store_url': 'https://example.com',
            },
          },
          keys: const UpdateKeys.nested(),
        ).kind,
        UpdateKind.required,
      );
      expect(
        decide(
          {'min': '2', 'must': '1', 'link': 'https://example.com'},
          keys: const UpdateKeys(
            minimumVersion: 'min',
            forceUpdate: 'must',
            storeUrl: 'link',
          ),
        ).kind,
        UpdateKind.required,
      );
    });
  });

  group('RemoteValues', () {
    final values = RemoteValues({
      'name': ' x ',
      'on': 'true',
      'limit': '25',
      'style': {'mode': 'compact'},
      'list': '[1,2]',
      'blank': '  ',
    });

    test('typed getters fall back for missing, blank or wrong types', () {
      expect(values.string('name'), 'x');
      expect(values.string('blank', 'd'), 'd');
      expect(values.boolean('on'), true);
      expect(values.boolean('missing', true), true);
      expect(values.number('limit'), 25);
      expect(values.number('name', 7), 7);
      expect(values.json('list'), [1, 2]);
      expect(values.json('nope', 'fb'), 'fb');
    });

    test('reads dotted paths and exact keys', () {
      expect(values.string('style.mode'), 'compact');
      expect(RemoteValues({'a.b': 'exact'}).string('a.b'), 'exact');
      expect(values.has('style.mode'), true);
    });

    test('is deeply immutable', () {
      expect(
        () => (values.raw('style') as Map)['mode'] = 'x',
        throwsUnsupportedError,
      );
    });
  });
}
