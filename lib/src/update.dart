import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'values.dart';

/// The installed version (optionally `+build`) and the Android application ID.
class AppInfo {
  const AppInfo({required this.version, required this.packageName});

  final String version;
  final String packageName;

  static Future<AppInfo> fromPlatform() async {
    final info = await PackageInfo.fromPlatform();
    return AppInfo(
      version: info.buildNumber.isEmpty
          ? info.version
          : '${info.version}+${info.buildNumber}',
      packageName: info.packageName,
    );
  }
}

/// `android` or `ios`; null (web, desktop) means there is no update check.
String? detectPlatform() => kIsWeb
    ? null
    : switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        _ => null,
      };

/// Which remote keys drive the update decision.
///
/// Each value is a key or dotted path; `{platform}` becomes `android` or `ios`.
/// The defaults match the keys `android_version`, `ios_version`,
/// `android_store_link`, `ios_store_link` and one shared `force_update`.
class UpdateKeys {
  const UpdateKeys({
    this.minimumVersion = '{platform}_version',
    this.latestVersion = '{platform}_latest_version',
    this.storeUrl = '{platform}_store_link',
    this.forceUpdate = 'force_update',
  });

  /// `<prefix>_android_version`, `<prefix>_force_update`, … for apps that share
  /// one Remote Config project.
  const UpdateKeys.prefixed(String prefix)
    : minimumVersion = '${prefix}_{platform}_version',
      latestVersion = '${prefix}_{platform}_latest_version',
      storeUrl = '${prefix}_{platform}_store_link',
      forceUpdate = '${prefix}_force_update';

  /// JSON shaped as `{"android": {"minimum_version": …}, "ios": {…}}`.
  const UpdateKeys.nested()
    : minimumVersion = '{platform}.minimum_version',
      latestVersion = '{platform}.latest_version',
      storeUrl = '{platform}.store_url',
      forceUpdate = '{platform}.force_update';

  final String minimumVersion;
  final String latestVersion;
  final String storeUrl;
  final String forceUpdate;
}

/// Whether the app continues, prompts optionally, or requires an update.
enum UpdateKind { none, optional, required }

/// A decision and the version/destination to present to the user.
class UpdateResult {
  const UpdateResult(this.kind, {this.version, this.destination});

  const UpdateResult.none() : this(UpdateKind.none);

  final UpdateKind kind;
  final String? version;
  final Uri? destination;

  bool get isRequired => kind == UpdateKind.required;
  bool get isAvailable => kind != UpdateKind.none;
  String get identity => '${kind.name}:$version:$destination';
}

/// Returns negative, zero or positive like `compareTo`; throws on bad input.
typedef VersionComparator = int Function(String installed, String remote);

/// Dotted numbers (missing parts are zero), then the numeric `+build`.
int compareVersions(String installed, String remote) {
  (List<int>, int) parse(String text) {
    if (!RegExp(r'^\d+(\.\d+)*(\+\d+)?$').hasMatch(text)) {
      throw FormatException('Invalid app version', text);
    }
    final parts = text.split('+');
    return (
      parts.first.split('.').map(int.parse).toList(),
      parts.length == 2 ? int.parse(parts.last) : 0,
    );
  }

  final (a, aBuild) = parse(installed);
  final (b, bBuild) = parse(remote);
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final result = (i < a.length ? a[i] : 0).compareTo(i < b.length ? b[i] : 0);
    if (result != 0) return result;
  }
  return aBuild.compareTo(bBuild);
}

/// Required when forced and below the minimum, optional when below the latest.
///
/// Throws [FormatException] for malformed versions, a latest version below the
/// minimum, or a missing store destination, so the caller keeps its last good
/// snapshot instead.
UpdateResult evaluateUpdate({
  required RemoteValues values,
  required UpdateKeys keys,
  required AppInfo app,
  required String? platform,
  VersionComparator compare = compareVersions,
}) {
  if (platform == null) return const UpdateResult.none();
  String text(String template) =>
      values.string(template.replaceAll('{platform}', platform));

  final minimum = text(keys.minimumVersion);
  final latest = text(keys.latestVersion);
  final force = values.boolean(
    keys.forceUpdate.replaceAll('{platform}', platform),
  );
  for (final version in [app.version, minimum, latest]) {
    if (version.isNotEmpty) compare(version, version);
  }
  if (minimum.isNotEmpty &&
      latest.isNotEmpty &&
      compare(minimum, latest) > 0) {
    throw const FormatException('Latest version is below minimum version');
  }

  final kind = force &&
          minimum.isNotEmpty &&
          compare(app.version, minimum) < 0
      ? UpdateKind.required
      : latest.isNotEmpty && compare(app.version, latest) < 0
      ? UpdateKind.optional
      : UpdateKind.none;
  if (kind == UpdateKind.none) return const UpdateResult.none();

  final destination = _destination(text(keys.storeUrl), platform, app);
  if (!_isUsable(destination)) {
    throw const FormatException('Update needs a usable store destination');
  }
  return UpdateResult(
    kind,
    version: kind == UpdateKind.required ? minimum : latest,
    destination: destination,
  );
}

/// The configured link, or the Play Store page derived from the package name.
Uri? _destination(String url, String platform, AppInfo app) {
  if (url.isNotEmpty) return Uri.tryParse(url);
  if (platform == 'android' && app.packageName.isNotEmpty) {
    return Uri.https('play.google.com', '/store/apps/details', {
      'id': app.packageName,
    });
  }
  return null;
}

/// HTTP(S), Play `market://details?id=…` and `itms-apps://…` links.
bool _isUsable(Uri? uri) =>
    uri != null &&
    switch (uri.scheme) {
      'https' || 'http' || 'itms-apps' => uri.host.isNotEmpty,
      'market' => uri.host == 'details' && uri.queryParameters.containsKey('id'),
      _ => false,
    };
