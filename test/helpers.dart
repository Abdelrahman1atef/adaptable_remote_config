import 'package:adaptable_remote_config/adaptable_remote_config.dart';

/// Remote values in the default `{platform}_version` layout.
Map<String, dynamic> remote({
  String? minimum = '2',
  String? latest,
  bool force = true,
  String url = 'https://example.com/update',
  String baseUrl = 'https://api.example',
}) => {
  for (final platform in ['android', 'ios']) ...{
    '${platform}_version': ?minimum,
    '${platform}_latest_version': ?latest,
    '${platform}_store_link': url,
  },
  'force_update': '$force',
  'base_url': baseUrl,
};

RemoteConfigController controller(
  Future<Map<String, dynamic>> Function() loader, {
  ConfigStorage? storage,
  Duration timeout = const Duration(seconds: 1),
  DateTime Function()? clock,
  Future<bool> Function(UpdateResult)? openStore,
  Future<bool> Function(UpdateResult)? inAppUpdate,
  RemoteConfigLogger? log,
  Stream<void>? changes,
}) => RemoteConfigController(
  provider: CustomConfigProvider(loader, changes: changes),
  appId: 'test',
  storage: storage ?? MemoryConfigStorage(),
  defaults: const {'base_url': 'https://default.example'},
  appInfo: () async =>
      const AppInfo(version: '1+1', packageName: 'com.example.app'),
  platform: 'android',
  requestTimeout: timeout,
  startupWait: timeout,
  clock: clock ?? DateTime.now,
  openStore: openStore,
  inAppUpdate: inAppUpdate,
  log: log,
  subscribeToChanges: changes != null,
);
