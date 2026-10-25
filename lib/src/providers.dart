import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;

import 'values.dart';

/// A source of remote key/value pairs. Providers just throw on failure; the
/// controller falls back to its cache.
abstract class RemoteConfigProvider {
  /// The latest values as a flat or nested JSON-compatible map.
  Future<Map<String, dynamic>> fetch();

  /// Each event means "values changed, fetch again".
  Stream<void> get changes => const Stream.empty();

  Future<void> dispose() async {}
}

/// Any async function that returns a map: an existing API client, a database…
class CustomConfigProvider extends RemoteConfigProvider {
  CustomConfigProvider(this.loader, {Stream<void>? changes, this.onDispose})
    : _changes = changes ?? const Stream.empty();

  final Future<Map<String, dynamic>> Function() loader;
  final Stream<void> _changes;
  final Future<void> Function()? onDispose;

  @override
  Future<Map<String, dynamic>> fetch() => loader();

  @override
  Stream<void> get changes => _changes;

  @override
  Future<void> dispose() async => onDispose?.call();
}

/// Fetches a JSON object. [root] is the dotted path of the config object when
/// the response wraps it (`data.apps.my_app`).
class HttpConfigProvider extends RemoteConfigProvider {
  HttpConfigProvider({
    required this.url,
    this.root,
    this.method = 'GET',
    this.headers = const {},
    this.body,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final Uri url;
  final String? root;
  final String method;
  final Map<String, String> headers;
  final Object? body;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<Map<String, dynamic>> fetch() async {
    final request = http.Request(method, url)..headers.addAll(headers);
    if (body != null) {
      request.headers.putIfAbsent('content-type', () => 'application/json');
      request.body = body is String ? body as String : jsonEncode(body);
    }
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('Config HTTP ${response.statusCode}', url);
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    final object = json is Map<String, dynamic> && root != null
        ? readPath(json, root!)
        : json;
    if (object is! Map) {
      throw const FormatException('Expected a JSON configuration object');
    }
    return Map<String, dynamic>.from(object);
  }

  @override
  Future<void> dispose() async {
    if (_ownsClient) _client.close();
  }
}

/// Firebase Remote Config. The host initializes Firebase first.
///
/// [defaults] replace any set elsewhere with `setDefaults`, so list every key
/// the app reads. Real-time updates are exposed through [changes].
class FirebaseConfigProvider extends RemoteConfigProvider {
  FirebaseConfigProvider({
    FirebaseRemoteConfig? remoteConfig,
    this.defaults = const {},
    this.fetchTimeout = const Duration(seconds: 4),
    this.minimumFetchInterval = const Duration(hours: 1),
  }) : remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig remoteConfig;
  final Map<String, dynamic> defaults;
  final Duration fetchTimeout;
  final Duration minimumFetchInterval;
  Future<void>? _setup;
  bool _activatedEvent = false;

  Future<void> _initialize() async {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: fetchTimeout,
        minimumFetchInterval: minimumFetchInterval,
      ),
    );
    if (defaults.isNotEmpty) await remoteConfig.setDefaults(defaults);
    await remoteConfig.ensureInitialized();
  }

  @override
  Future<Map<String, dynamic>> fetch() async {
    try {
      await (_setup ??= _initialize());
    } catch (_) {
      _setup = null;
      rethrow;
    }
    // A real-time event already fetched its values; only activate them.
    if (_activatedEvent) {
      _activatedEvent = false;
      await remoteConfig.activate();
    } else {
      await remoteConfig.fetchAndActivate();
    }
    return {
      for (final entry in remoteConfig.getAll().entries)
        entry.key: entry.value.asString(),
    };
  }

  @override
  Stream<void> get changes => remoteConfig.onConfigUpdated.map((_) {
    _activatedEvent = true;
  });
}
