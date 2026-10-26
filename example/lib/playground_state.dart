import 'dart:async';
import 'dart:convert';

import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Where the values come from. Both are simulated, so no server is needed.
enum SourceKind {
  /// `CustomConfigProvider`: any function that returns a map.
  custom,

  /// `HttpConfigProvider`: a JSON file (answered by a fake web server here).
  http,
}

/// How much of the screen you replace (see the README, "Change the look").
enum CardStyle { standard, custom, banner, ownScreens }

enum IconStyle { round, image, builder }

/// What Google Play's in-app update would do when the user taps Update.
enum PlayHook { off, handled, notHandled }

enum DirectionMode { auto, ltr, rtl }

/// One-tap setups, each showing a different row of the README decision table.
enum Preset { upToDate, optional, force, wallWins, mistake, iosNoLink }

/// What an admin types in for one platform.
class PlatformValues {
  PlatformValues({this.minimum = '1.0.0+1', this.latest = '1.0.0+1', this.store = ''});

  String minimum;
  String latest;
  String store;

  PlatformValues copy() =>
      PlatformValues(minimum: minimum, latest: latest, store: store);
}

/// A complete set of "server" values.
class ServerValues {
  ServerValues({
    PlatformValues? android,
    PlatformValues? ios,
    this.force = false,
    this.welcome = 'Welcome to the demo app',
  }) : android = android ?? PlatformValues(),
       ios = ios ?? PlatformValues();

  PlatformValues android;
  PlatformValues ios;
  bool force;
  String welcome;

  ServerValues copy() => ServerValues(
    android: android.copy(),
    ios: ios.copy(),
    force: force,
    welcome: welcome,
  );

  /// Flat keys: what Firebase Remote Config or your own function returns.
  Map<String, dynamic> toFlat() => {
    'android_version': android.minimum,
    'android_latest_version': android.latest,
    'android_store_link': android.store,
    'ios_version': ios.minimum,
    'ios_latest_version': ios.latest,
    'ios_store_link': ios.store,
    'force_update': force.toString(),
    'welcome_message': welcome,
  };

  /// Nested keys: the JSON file served by `HttpConfigProvider`.
  Map<String, dynamic> toNested() => {
    for (final entry in {'android': android, 'ios': ios}.entries)
      entry.key: {
        'minimum_version': entry.value.minimum,
        'latest_version': entry.value.latest,
        'store_url': entry.value.store,
        'force_update': force,
      },
    'welcome_message': welcome,
  };
}

/// One boxed block of log lines, as printed by `RemoteConfigLogger`.
class LogBox {
  LogBox(this.title) : time = DateTime.now();

  final String title;
  final DateTime time;
  final List<String> lines = [];
}

/// Everything the playground changes: the fake server, the fake phone, the fake
/// store, the look, and the controller that reads them.
class PlaygroundState extends ChangeNotifier {
  PlaygroundState({this.toastFor = const Duration(seconds: 4)}) {
    controller = _build();
  }

  /// How long the message above the pill stays (tests make it short).
  final Duration toastFor;

  // ---- the fake server -----------------------------------------------------
  /// What you are typing (like the Firebase console before "Publish changes").
  ServerValues draft = ServerValues();

  /// What the "server" really serves (after "Publish changes").
  ServerValues live = ServerValues();

  bool get hasUnpublished =>
      jsonEncode(draft.toFlat()) != jsonEncode(live.toFlat());

  // ---- the fake phone ------------------------------------------------------
  String platform = 'android';
  String installedVersion = '1.0.0+1';
  SourceKind source = SourceKind.custom;
  bool offline = false;
  bool pushOnPublish = true;

  // ---- the fake store ------------------------------------------------------
  bool storeOpens = true;
  PlayHook playHook = PlayHook.off;

  // ---- the look ------------------------------------------------------------
  ThemeMode themeMode = ThemeMode.light;
  bool arabic = false;
  DirectionMode direction = DirectionMode.auto;
  IconStyle icon = IconStyle.round;
  CardStyle card = CardStyle.standard;
  bool showOptional = true;
  bool allowSkip = true;

  // ---- output --------------------------------------------------------------
  final List<LogBox> logs = [];
  bool echoLogs = false;
  final ValueNotifier<String?> toast = ValueNotifier(null);

  /// Whether the playground sheet is open (closing it shows the update screen).
  final ValueNotifier<bool> panelOpen = ValueNotifier(false);
  Timer? _toastTimer;

  late RemoteConfigController controller;
  final StreamController<void> _push = StreamController<void>.broadcast();
  MemoryConfigStorage _storage = MemoryConfigStorage();

  TextDirection? get forcedDirection => switch (direction) {
    DirectionMode.auto => null,
    DirectionMode.ltr => TextDirection.ltr,
    DirectionMode.rtl => TextDirection.rtl,
  };

  RemoteConfigController _build() {
    final custom = source == SourceKind.custom;
    return RemoteConfigController(
      appId: 'playground',
      provider: custom
          ? CustomConfigProvider(() async {
              if (offline) throw StateError('No internet (simulated)');
              return live.toFlat();
            }, changes: _push.stream)
          : HttpConfigProvider(
              url: Uri.parse('https://demo.example.com/app_config.json'),
              // A fake web server: answers with the published JSON.
              client: MockClient((_) async {
                if (offline) return http.Response('Service unavailable', 503);
                return http.Response(
                  jsonEncode(live.toNested()),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }),
            ),
      keys: custom ? const UpdateKeys() : const UpdateKeys.nested(),
      appInfo: () async =>
          AppInfo(version: installedVersion, packageName: 'com.example.demo'),
      platform: platform,
      storage: _storage,
      openStore: _openStore,
      inAppUpdate: playHook == PlayHook.off ? null : _playUpdate,
      // A real-time push only exists for sources that can send one.
      subscribeToChanges: custom,
      startupWait: const Duration(seconds: 2),
      requestTimeout: const Duration(seconds: 2),
      log: RemoteConfigLogger(print: _onLogLine),
    );
  }

  /// The user taps Update. Nothing is really opened, so the demo is safe.
  Future<bool> _openStore(UpdateResult result) async {
    say(
      storeOpens
          ? 'Would open the store: ${result.destination}'
          : 'The store could not be opened (simulated)',
    );
    return storeOpens;
  }

  /// Plays the part of Google Play's in-app update screen.
  Future<bool> _playUpdate(UpdateResult result) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (playHook == PlayHook.handled) {
      say('Google Play update screen handled it');
      return true;
    }
    say('Play update not available, using the store page');
    return false;
  }

  void _onLogLine(String line) {
    if (line.startsWith('╔')) {
      final title = line.split('·').last.trim();
      logs.insert(0, LogBox(title));
      if (logs.length > 60) logs.removeLast();
    } else if (logs.isNotEmpty && line.startsWith('║')) {
      logs.first.lines.add(line.substring(1).trim());
    }
    if (echoLogs) debugPrint(line);
    notifyListeners();
  }

  /// A short message above the playground pill.
  void say(String message) {
    toast.value = message;
    _toastTimer?.cancel();
    _toastTimer = Timer(toastFor, () => toast.value = null);
  }

  // ---- actions -------------------------------------------------------------
  /// Starts the app again, like closing it and opening it (a new controller).
  void restart() {
    final old = controller;
    controller = _build();
    notifyListeners();
    // The gate switches to the new controller first, then the old one goes.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  /// Forgets the saved copy and the "Later" / "Skip" answers.
  void forgetEverything() {
    _storage = MemoryConfigStorage();
    restart();
  }

  /// Like pressing "Publish changes" in the Firebase console.
  void publish() {
    live = draft.copy();
    if (pushOnPublish && source == SourceKind.custom) _push.add(null);
    say(
      pushOnPublish && source == SourceKind.custom
          ? 'Published, and pushed to the open app'
          : 'Published. The app gets it on its next fetch or start',
    );
    notifyListeners();
  }

  Future<void> fetchNow() async {
    await controller.refresh();
    notifyListeners();
  }

  Future<void> applyPreset(Preset preset) async {
    if (preset == Preset.iosNoLink) {
      // An iPhone with no App Store link: the update cannot be shown.
      draft.ios
        ..minimum = '2.0.0+1'
        ..latest = '2.0.0+1'
        ..store = '';
      draft.force = true;
      platform = 'ios';
      publish();
      restart();
      panelOpen.value = false;
      return;
    }
    final p = platform == 'ios' ? draft.ios : draft.android;
    switch (preset) {
      case Preset.upToDate:
        _set(p, '1.0.0+1', '1.0.0+1', false);
      case Preset.optional:
        _set(p, '1.0.0+1', '2.0.0+1', false);
      case Preset.force:
        _set(p, '2.0.0+1', '2.0.0+1', true);
      case Preset.wallWins:
        _set(p, '2.0.0+1', '3.0.0+1', true);
      case Preset.mistake:
        _set(p, '3.0.0+1', '2.0.0+1', true);
      case Preset.iosNoLink:
        break;
    }
    // iOS needs a store link; Android builds one from the package name.
    if (platform == 'ios' && p.store.isEmpty) {
      p.store = 'https://apps.apple.com/app/id1234567890';
    }
    publish();
    // Show the result: the sheet would cover the dialog.
    panelOpen.value = false;
    await fetchNow();
  }

  void _set(PlatformValues p, String min, String latest, bool force) {
    p.minimum = min;
    p.latest = latest;
    draft.force = force;
  }

  // ---- setters that need a new controller ----------------------------------
  void setPlatform(String value) {
    platform = value;
    restart();
  }

  void setInstalled(String value) {
    installedVersion = value.trim();
    restart();
  }

  void setSource(SourceKind value) {
    source = value;
    restart();
  }

  void setPlayHook(PlayHook value) {
    playHook = value;
    restart();
  }

  /// Redraws (the look changes never need a new controller).
  void changed() => notifyListeners();

  /// A sentence for what the app decided, shown at the top of the playground.
  String get verdict {
    final update = controller.update;
    final error = controller.error;
    final mistake = error is FormatException
        ? ' (the last change had a mistake, so it was ignored: ${error.message})'
        : '';
    return switch (update.kind) {
      UpdateKind.none => 'NOTHING: the user is let in$mistake',
      UpdateKind.optional => 'DIALOG: latest ${update.version}$mistake',
      UpdateKind.required => 'WALL: minimum ${update.version}$mistake',
    };
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    controller.dispose();
    _push.close();
    toast.dispose();
    panelOpen.dispose();
    super.dispose();
  }
}
