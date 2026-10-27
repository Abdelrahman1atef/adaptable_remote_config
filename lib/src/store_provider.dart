import 'dart:convert';

import 'package:http/http.dart' as http;

import 'providers.dart';
import 'update.dart';

/// What a store says about the newest release of this app.
class StoreRelease {
  /// A release known only by its build number (Google Play gives just that).
  /// The version name of the installed app is reused.
  const StoreRelease.build(int this.build, {this.force = false})
    : version = null,
      link = null;

  /// A release with a full version, such as `2.1.0` (the App Store gives that).
  const StoreRelease.version(String this.version, {this.link, this.force = false})
    : build = null;

  final String? version;
  final int? build;

  /// The store page to open; null opens the default page for the app.
  final String? link;

  /// The store asks for a blocking update (Google Play update priority 4 or 5).
  final bool force;
}

/// Asks the store itself which version is newest. There is nothing to edit
/// anywhere and no server to run.
///
/// * **iOS** is built in: the App Store lookup API gives the newest version and
///   the store page. It can only ever be an optional update.
/// * **Android** needs Google Play, which only an Android plugin can ask. Pass
///   [android] a function that does it (the setup wizard writes one for you
///   with `in_app_update`). A release with `force: true` becomes a blocking
///   update.
///
/// The values it returns use the standard keys, so give the controller the
/// default `UpdateKeys()`.
class StoreConfigProvider extends RemoteConfigProvider {
  StoreConfigProvider({
    this.android,
    this.iosBundleId,
    this.country,
    this.keys = const UpdateKeys(),
    Future<AppInfo> Function() appInfo = AppInfo.fromPlatform,
    String? platform,
    http.Client? client,
  }) : _appInfo = appInfo,
       _platform = platform,
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  /// Returns the newest Google Play release, or null when there is none newer.
  final Future<StoreRelease?> Function()? android;

  /// The App Store bundle id; defaults to the installed app's id.
  final String? iosBundleId;

  /// Two-letter App Store country (`us`, `eg`...). The store the app is sold in.
  final String? country;

  final UpdateKeys keys;
  final Future<AppInfo> Function() _appInfo;
  final String? _platform;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<Map<String, dynamic>> fetch() async {
    final platform = _platform ?? detectPlatform();
    if (platform == null) return {};
    final app = await _appInfo();
    final release = switch (platform) {
      'android' => await android?.call(),
      'ios' => await _lookupIos(app),
      _ => null,
    };
    final installedName = app.version.split('+').first;
    final latest = release == null
        ? app.version
        : release.version ??
              (release.build == null
                  ? app.version
                  : '$installedName+${release.build}');
    String key(String template) => template.replaceAll('{platform}', platform);
    return {
      key(keys.latestVersion): latest,
      key(keys.storeUrl): release?.link ?? '',
      key(keys.forceUpdate): '${release?.force ?? false}',
      if (release?.force ?? false) key(keys.minimumVersion): latest,
    };
  }

  Future<StoreRelease?> _lookupIos(AppInfo app) async {
    final query = {
      'bundleId': iosBundleId ?? app.packageName,
      'country': ?country,
    };
    final uri = Uri.https('itunes.apple.com', '/lookup', query);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw http.ClientException('App Store lookup answered ${response.statusCode}', uri);
    }
    final results = (jsonDecode(response.body) as Map)['results'];
    // Not in the store (yet): nothing to offer.
    if (results is! List || results.isEmpty) return null;
    final first = results.first as Map;
    final version = first['version'];
    if (version is! String || version.isEmpty) return null;
    return StoreRelease.version(version, link: first['trackViewUrl'] as String?);
  }

  @override
  Future<void> dispose() async {
    if (_ownsClient) _client.close();
  }
}
