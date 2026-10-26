import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every row of the "decision table" in the README, run against the real code.
/// If this file changes, change the README table too.
const _installed = AppInfo(version: '1.2.0+4', packageName: 'com.example.app');
const _store = 'https://example.com/update';

/// What the README calls: Nothing / Dialog / Wall.
String _decide({
  String? minimum,
  String? latest,
  bool force = false,
  String? store = _store,
  String platform = 'android',
  AppInfo app = _installed,
}) {
  final values = <String, dynamic>{
    '${platform}_version': ?minimum,
    '${platform}_latest_version': ?latest,
    'force_update': force,
    '${platform}_store_link': ?store,
  };
  final result = evaluateUpdate(
    values: RemoteValues(values),
    keys: const UpdateKeys(),
    app: app,
    platform: platform,
  );
  return switch (result.kind) {
    UpdateKind.none => 'Nothing',
    UpdateKind.optional => 'Dialog',
    UpdateKind.required => 'Wall',
  };
}

void main() {
  group('main table (installed app is 1.2.0+4)', () {
    test('1. nothing is set', () {
      expect(_decide(), 'Nothing');
    });

    test('2. force is off: the minimum is ignored', () {
      expect(_decide(minimum: '2.0.0'), 'Nothing');
      expect(_decide(minimum: '9.9.9', force: false), 'Nothing');
    });

    test('3. force is on and installed is below the minimum: Wall', () {
      expect(_decide(minimum: '2.0.0', force: true), 'Wall');
      expect(_decide(minimum: '1.2.0+5', force: true), 'Wall');
    });

    test('4. force is on but installed meets the minimum: no wall', () {
      expect(_decide(minimum: '1.2.0+4', force: true), 'Nothing');
      expect(_decide(minimum: '1.0.0', force: true), 'Nothing');
    });

    test('5. force is on but no minimum is set: nothing to enforce', () {
      expect(_decide(force: true), 'Nothing');
    });

    test('6. installed is below the latest: Dialog', () {
      expect(_decide(latest: '2.0.0'), 'Dialog');
      expect(_decide(latest: '1.2.0+5'), 'Dialog');
    });

    test('7. installed equals or beats the latest: Nothing', () {
      expect(_decide(latest: '1.2.0+4'), 'Nothing');
      expect(_decide(latest: '1.0.0'), 'Nothing');
    });

    test('8. the Wall wins over the Dialog', () {
      expect(_decide(minimum: '2.0.0', latest: '3.0.0', force: true), 'Wall');
    });

    test('9. above the minimum but below the latest: Dialog', () {
      expect(_decide(minimum: '1.0.0', latest: '2.0.0', force: true), 'Dialog');
    });

    test('10. force off, minimum high, latest high: Dialog (not a Wall)', () {
      expect(_decide(minimum: '2.0.0', latest: '3.0.0'), 'Dialog');
    });
  });

  group('mistakes are ignored, never shown', () {
    test('11. a minimum above the latest is rejected', () {
      expect(
        () => _decide(minimum: '3.0.0', latest: '2.0.0', force: true),
        throwsFormatException,
      );
    });

    test('12. a version that is not 1.2.3 or 1.2.3+4 is rejected', () {
      for (final bad in ['abc', '1.2.0-beta', 'v2', '2.0.', '1..0']) {
        expect(
          () => _decide(minimum: bad, force: true),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('13. blank values count as "not set"', () {
      expect(_decide(minimum: '  ', latest: '', force: true), 'Nothing');
    });
  });

  group('the store link', () {
    test('14. Android: a blank link is fine (Play Store page is built)', () {
      expect(_decide(minimum: '2.0.0', force: true, store: ''), 'Wall');
      expect(_decide(minimum: '2.0.0', force: true, store: null), 'Wall');
    });

    test('15. iOS: a blank link means the update cannot be shown', () {
      expect(
        () => _decide(minimum: '2.0.0', force: true, store: '', platform: 'ios'),
        throwsFormatException,
      );
    });

    test('16. iOS: a blank link is fine while nothing needs to show', () {
      expect(_decide(store: '', platform: 'ios'), 'Nothing');
    });

    test('17. a link that is not a real address is rejected', () {
      for (final bad in ['www.example.com', 'example.com', 'javascript:x']) {
        expect(
          () => _decide(minimum: '2.0.0', force: true, store: bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('18. https, http, market:// and itms-apps:// links are accepted', () {
      for (final good in [
        'https://play.google.com/store/apps/details?id=com.example.app',
        'http://example.com/app',
        'market://details?id=com.example.app',
        'itms-apps://apps.apple.com/app/id1',
      ]) {
        expect(_decide(minimum: '2.0.0', force: true, store: good), 'Wall', reason: good);
      }
    });
  });

  group('platforms', () {
    test('19. Android reads android_*, iOS reads ios_*', () {
      const values = {
        'android_version': '2.0.0',
        'ios_version': '1.0.0',
        'force_update': true,
        'android_store_link': _store,
        'ios_store_link': _store,
      };
      String on(String platform) => evaluateUpdate(
        values: RemoteValues(values),
        keys: const UpdateKeys(),
        app: _installed,
        platform: platform,
      ).kind.name;
      expect(on('android'), 'required');
      expect(on('ios'), 'none');
    });

    test('20. other platforms (web, desktop) are never asked to update', () {
      final result = evaluateUpdate(
        values: RemoteValues(const {
          'android_version': '9.0.0',
          'force_update': true,
          'android_store_link': _store,
        }),
        keys: const UpdateKeys(),
        app: _installed,
        platform: null,
      );
      expect(result.kind, UpdateKind.none);
    });
  });

  group('how versions are compared', () {
    test('21. each part is a number; a missing part is 0; a missing build is +0', () {
      String vs(String installed, String latest) => _decide(
        latest: latest,
        app: AppInfo(version: installed, packageName: 'p'),
      );
      expect(vs('1.2.0+4', '1.2.0+5'), 'Dialog'); // build number counts
      expect(vs('1.2.0+5', '1.2.0+4'), 'Nothing');
      expect(vs('1.9.0', '1.10.0'), 'Dialog'); // 10 is bigger than 9
      expect(vs('1.2', '1.2.0'), 'Nothing'); // 1.2 is the same as 1.2.0
      expect(vs('1.2.0', '1.2.0+1'), 'Dialog'); // no build means +0
    });
  });
}
