import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'providers.dart';
import 'storage.dart';
import 'update.dart';
import 'values.dart';

/// Loads remote values, decides whether the app must update, and remembers the
/// user's "Later" / "Skip" answers.
///
/// Listen with [addListener] or `ListenableBuilder`. The host owns the
/// controller and calls [dispose]; the controller owns its provider.
class RemoteConfigController extends ChangeNotifier {
  RemoteConfigController({
    required this.provider,
    required this.appId,
    this.keys = const UpdateKeys(),
    this.defaults = const {},
    ConfigStorage? storage,
    this.appInfo = AppInfo.fromPlatform,
    String? platform,
    this.comparator = compareVersions,
    this.openStore,
    this.startupWait = const Duration(seconds: 4),
    this.requestTimeout = const Duration(seconds: 4),
    this.refreshInterval = const Duration(hours: 1),
    this.remindAfter = const Duration(days: 1),
    this.subscribeToChanges = false,
    this.clock = DateTime.now,
    this.onError,
  }) : storage = storage ?? PreferencesConfigStorage(),
       platform = platform ?? detectPlatform() {
    _values = RemoteValues(defaults);
  }

  final RemoteConfigProvider provider;

  /// Scopes the persistent cache, so two apps never share a snapshot.
  final String appId;

  final UpdateKeys keys;

  /// Local values used until (and underneath) the remote ones.
  final Map<String, dynamic> defaults;
  final ConfigStorage storage;
  final Future<AppInfo> Function() appInfo;
  final String? platform;
  final VersionComparator comparator;

  /// Replaces the default "open the store link" action.
  final Future<bool> Function(UpdateResult result)? openStore;
  final Duration startupWait;
  final Duration requestTimeout;
  final Duration refreshInterval;
  final Duration remindAfter;
  final bool subscribeToChanges;
  final DateTime Function() clock;
  final void Function(Object error, StackTrace stack)? onError;

  late RemoteValues _values;
  UpdateResult _update = const UpdateResult.none();
  Object? _error;
  Object? _actionError;
  bool _ready = false;
  bool _opening = false;
  bool _disposed = false;
  bool _stale = false;
  AppInfo? _app;
  Future<void>? _initialization;
  Future<UpdateResult>? _refreshing;
  StreamSubscription<void>? _subscription;
  DateTime? _lastAttempt;
  String? _skipped;
  String? _dismissed;
  DateTime? _remindAt;

  /// Defaults overlaid with the last valid remote snapshot.
  RemoteValues get values => _values;

  /// The current decision.
  UpdateResult get update => _update;

  /// The latest provider, validation, storage or launch error.
  Object? get error => _error;

  /// A failed store launch; cleared by the next attempt.
  Object? get actionError => _actionError;

  /// Startup finished, or its [startupWait] elapsed.
  bool get isReady => _ready;

  bool get isOpeningUpdate => _opening;

  String get _cacheKey => 'adaptable_remote_config.v2.$appId';
  String get _promptsKey => '$_cacheKey.prompts';

  /// An optional update the user has not postponed or skipped.
  bool get shouldPrompt {
    if (_update.kind != UpdateKind.optional) return false;
    if (_skipped == _update.version) return false;
    final remindAt = _remindAt;
    return _dismissed != _update.version ||
        remindAt == null ||
        !clock().isBefore(remindAt);
  }

  /// Completes within [startupWait]; a late success still notifies listeners.
  Future<void> initialize() {
    _ensureAlive();
    return _initialization ??= _initialize().timeout(
      startupWait,
      onTimeout: () {
        _ready = true;
        _notify();
      },
    );
  }

  Future<void> _initialize() async {
    try {
      _app = await appInfo().timeout(requestTimeout);
      comparator(_app!.version, _app!.version);
      await _restore();
      if (subscribeToChanges && !_disposed) {
        _subscription = provider.changes.listen(
          (_) {
            _stale = true;
            _refetchIfStale();
          },
          onError: (Object error, StackTrace stack) => _report(error, stack),
        );
      }
      await _refresh(force: true);
    } catch (error, stack) {
      _report(error, stack);
    } finally {
      _ready = true;
      _notify();
    }
  }

  /// Loads the cached snapshot and the saved prompt answers.
  Future<void> _restore() async {
    try {
      final cached = await storage.read(_cacheKey).timeout(requestTimeout);
      if (cached != null && !_disposed) _accept(cached);
      final prompts = await storage.read(_promptsKey).timeout(requestTimeout);
      _skipped = prompts?['skipped'] as String?;
      _dismissed = prompts?['dismissed'] as String?;
      _remindAt = DateTime.tryParse(prompts?['remind_at'] as String? ?? '');
    } catch (error, stack) {
      _report(error, stack);
    }
  }

  /// Fetches new values. [force] false skips the call when the last attempt is
  /// younger than [refreshInterval]. Firebase applies its own throttle too.
  Future<UpdateResult> refresh({bool force = true}) async {
    _ensureAlive();
    if (!_ready) {
      await initialize();
      return _refreshing ?? _update;
    }
    return _refresh(force: force);
  }

  Future<UpdateResult> _refresh({required bool force}) {
    if (_refreshing != null) return _refreshing!;
    if (_app == null || _disposed) return Future.value(_update);
    final recent =
        _lastAttempt != null &&
        clock().difference(_lastAttempt!) < refreshInterval;
    if (!force && recent) return Future.value(check());
    return _refreshing = _fetch().whenComplete(() {
      _refreshing = null;
      _refetchIfStale();
    });
  }

  Future<UpdateResult> _fetch() async {
    _lastAttempt = clock();
    try {
      final remote = await provider.fetch().timeout(requestTimeout);
      if (!_disposed) {
        _accept(remote);
        _error = null;
        await _save(_cacheKey, _values.toJson());
      }
    } catch (error, stack) {
      _report(error, stack);
    }
    _notify();
    return _update;
  }

  void _refetchIfStale() {
    if (_disposed || !_stale || _refreshing != null) return;
    _stale = false;
    unawaited(_refresh(force: true));
  }

  /// Validates a snapshot and adopts it; throws and keeps the previous one if
  /// it cannot be cached or evaluated.
  void _accept(Map<String, dynamic> remote) {
    final merged = RemoteValues({...defaults, ...remote});
    jsonEncode(merged.toJson());
    _setUpdate(_evaluate(merged));
    _values = merged;
  }

  UpdateResult _evaluate(RemoteValues values) => evaluateUpdate(
    values: values,
    keys: keys,
    app: _app!,
    platform: platform,
    compare: comparator,
  );

  void _setUpdate(UpdateResult result) {
    if (_update.identity == result.identity) return;
    _update = result;
    _actionError = null;
  }

  /// Re-evaluates the current values without any I/O and notifies listeners.
  UpdateResult check() {
    _ensureAlive();
    if (_app != null) {
      try {
        _setUpdate(_evaluate(_values));
      } catch (error, stack) {
        _report(error, stack);
      }
    }
    _notify();
    return _update;
  }

  /// "Later" hides the prompt for [remindAfter]; [skipVersion] hides this
  /// version for good. A required update is never dismissible.
  Future<void> dismissOptional({bool skipVersion = false}) async {
    _ensureAlive();
    if (_update.kind != UpdateKind.optional) return;
    _dismissed = _update.version;
    _remindAt = clock().add(remindAfter);
    if (skipVersion) _skipped = _update.version;
    _notify();
    await _save(_promptsKey, {
      'dismissed': _dismissed,
      'remind_at': _remindAt?.toIso8601String(),
      'skipped': _skipped,
    });
  }

  /// Opens the store. Neither outcome lifts a required-update block; the next
  /// check does once the installed version is high enough.
  Future<bool> openUpdate() async {
    _ensureAlive();
    if (_opening || !_update.isAvailable) return false;
    _opening = true;
    _actionError = null;
    _notify();
    var success = false;
    try {
      success = openStore != null
          ? await openStore!(_update).timeout(requestTimeout)
          : await launchUrl(
              _update.destination!,
              mode: LaunchMode.externalApplication,
            ).timeout(requestTimeout);
      if (!success) throw StateError('Could not open update destination');
    } catch (error, stack) {
      if (!_disposed) _actionError = error;
      _report(error, stack);
    } finally {
      _opening = false;
      _notify();
    }
    return success;
  }

  Future<void> _save(String key, Map<String, dynamic> value) async {
    if (_disposed) return;
    try {
      await storage.write(key, value).timeout(requestTimeout);
    } catch (error, stack) {
      _report(error, stack);
    }
  }

  void _report(Object error, StackTrace stack) {
    if (_disposed) return;
    _error = error;
    try {
      onError?.call(error, stack);
    } catch (callbackError, callbackStack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: callbackError, stack: callbackStack),
      );
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('RemoteConfigController is disposed');
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription?.cancel());
    unawaited(provider.dispose());
    super.dispose();
  }
}
