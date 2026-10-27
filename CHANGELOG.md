## 0.7.3

- **The FETCHED log marks keys that are not on the server.** With Firebase, a key you deleted
  in the console still appears if your `defaults:` list names it. Such keys now end with
  `(default, not on the server)` and the box header counts them. New
  `RemoteConfigProvider.defaultKeys` (empty for the other providers).

## 0.7.2

- **The logs now say whether an optional dialog is really shown.** Under `=> DIALOG` the
  decision box adds `shown: yes` or `shown: NO` with the reason: the user tapped *Skip this
  version* (hidden until a newer latest version) or *Later* (hidden until the reminder time).
  Before, the log said DIALOG even when an earlier Skip kept it hidden, which looked like a bug.
- The saved Later / Skip answers are now loaded **before** the first decision, so the first
  log and decision after a restart are already correct.
- New `controller.forgetPromptAnswers()` clears every Later / Skip answer and saves that, for
  debug builds and "show update reminders again" settings.
- README: troubleshooting row, a note under the decision table, and a testing tip about
  Later / Skip being remembered on the phone.

## 0.7.1

- **Install is Flutter-first.** The package no longer declares an `executables:` entry, so the
  pub.dev "Installing" tab shows only `flutter pub add adaptable_remote_config` (it used to
  lead with `dart pub global activate`, a plain-Dart command). The setup tool is still run
  with `dart run adaptable_remote_config` from your Flutter app's folder. It now refuses a
  plain Dart project with a clear message. README gets an "Install" section: Flutter
  package, Android and iOS, Flutter 3.32+.
- **A full example app** (`example/`): a playground to try every feature with no Firebase and
  no server. Change the fake server's values and publish, pretend to be an Android phone or
  an iPhone, set the installed version, try every "Change the look" level, Arabic and
  right-to-left, a JSON file source served by a fake web server, offline, store failures,
  Google Play's in-app update, and read the logs. Runs on Android, iOS, web, Windows, macOS
  and Linux. CI tests and builds it on every change; every version tag attaches an
  installable APK to the GitHub release. Screenshots are on the pub.dev page.
- **A custom `cardBuilder` card (or any card) in `OptionalUpdateDialog` now scrolls** instead
  of overflowing on a short screen (a phone in landscape, very large text). The default
  card already did.

## 0.7.0

- **Breaking, from 0.6.0 (one day old): no more fixed icon path.** The package no longer
  reads `assets/app_icon.png` by itself. Pass your image to the gate:
  `UpdateGate(appIcon: const AssetImage('assets/images/logo.png'))`. `showAppIcon` and
  `defaultAppIconAsset` are removed. Without `appIcon` the round update icon is shown.
  `UpdateCard` now takes `icon: Widget` (it used to take `image` and an `IconData`).
- **Change the whole UI with builders, from small to total:**
  - `iconBuilder: (context, size) => ...` builds the icon: any widget (SVG, animation...).
  - `cardBuilder: (context, data) => ...` lays out the card yourself from ready-made parts
    in the new `UpdateCardData` (title, message, icon, update / later / skip buttons,
    error, kind, controller). The buttons stay wired. `UpdateCard.fromData(data)` is the
    default card, so you can wrap it.
  - `requiredBuilder`, `optionalBuilder` and `loadingBuilder` are unchanged.
  All of them work on `UpdateGate`, `RequiredUpdatePage` and `OptionalUpdateDialog`.
- **Wizard:** `--icon <asset path>` writes `appIcon:` into the gate it creates, checks
  the file exists, and tells you if it is not listed in `pubspec.yaml`. With no flag it
  offers a file named `app_icon.png`, `icon.png` or `logo.png` from `assets/` or
  `assets/images/` if it finds one; `--no-icon` skips.
- README: icon section rewritten around `appIcon:`; new "Change the look" with four
  levels (words, icon, card layout, whole screen) and a table of what `cardBuilder` gets.

## 0.6.0

- **Update card, rebuilt for both reading directions.** Everything uses start/end
  instead of left/right: icon, title, message and buttons sit on the correct side in
  left-to-right and right-to-left apps. Arabic texts are always drawn right-to-left, even
  inside a left-to-right app (`UpdateTexts.textDirection`, new). The card scrolls on small
  screens and with very large text instead of overflowing, and follows the app theme.
  New `UpdateCard` widget shared by the wall and the dialog.
- **Your app icon on the wall and dialog.** Put a square PNG at `assets/app_icon.png`
  (and list it in `pubspec.yaml`). No code. Missing file: the round update icon, no
  error. Another file or a web address: `UpdateGate(appIcon: ...)`; hide it with
  `showAppIcon: false`. The wizard reminds you where to put it.
- **Let Google Play do the update (Android).** New `inAppUpdate:` option on the
  controller, tried first when the user taps Update; returning false or throwing opens
  the store page as before. The wizard can write the helper for Google Play's immediate /
  flexible in-app update: `--play-update` (adds `in_app_update`). Documented with the
  limits (Play installs only, Android only; iOS cannot force an update).
- **Optional logs, like Dio's request logger.** `log: const RemoteConfigLogger()` prints
  every fetched key and value, what the app decided and why, errors and ignored values,
  and the user's taps. Off by default; secrets (`token`, `secret`, `password`,
  `api_key`) are printed as `***`; send lines to your own logger with `print:`.
- README: how a console change reaches the screen (and what real-time does not promise),
  the Firebase `Could not update ABT experiments` warning explained, new sections for the
  items above.

## 0.5.1

- README: a decision table that shows, for every combination of `force_update`,
  minimum and latest version, what the user sees (wall, dialog or nothing), and
  what happens with mistakes, store links, platforms and timing. Every row is
  checked by `test/decision_table_test.dart`, so the table cannot drift from the
  real behavior. No code changes.

## 0.5.0

- Several apps in one Firebase project: `--prefix <name>` names the keys
  `<name>_android_version`, `<name>_force_update`... and the wizard now creates
  them inside a Remote Config folder (parameter group) with the same name, so
  every app has its own folder in the console. `--group <name>` picks another
  folder name and `--no-group` skips the folder. The wizard also asks for the
  folder when you answer the questions. Existing keys and folders are never
  changed; a folder that already exists is extended.
- README rewritten as plain step-by-step guides for each method (Firebase, a
  JSON file, your own code), with how it works, what you need, how to test, and
  a troubleshooting table.

## 0.4.0

- The wizard can now create the Remote Config parameters for you, so there is
  nothing to click in the Firebase console. It uses the Firebase CLI login that
  `flutterfire configure` already needs (no service-account key). It reads the
  live template, shows exactly which parameters it will add, asks, publishes,
  then re-reads to verify.
- Safe by construction: parameters that already exist (at the top level or in
  a folder) are never changed or removed; it refuses to publish if the live
  template changed while it was running; with `--yes` nothing is written to
  Firebase unless you also pass `--publish`.
- New flags: `--publish`, `--no-publish`, `--project <id>`. The project id is
  read from `lib/firebase_options.dart` or `.firebaserc`.
- Without the Firebase CLI it prints the parameters to create, as before.

## 0.3.2

- The wizard no longer clobbers an app that is already set up. It stops when
  any file creates a `RemoteConfigController`, and it never adds a second
  `Firebase.initializeApp` when one exists anywhere in `lib/` (apps that start
  Firebase late on purpose, or tolerate a missing `firebase_options.dart`, were
  being moved onto the boot path and could crash).
- Imports follow the project's style: relative when the file already imports
  its own code that way, `package:` otherwise.

## 0.3.1

- Fix the setup wizard on Windows: arrow keys did not move the menu and the
  first run could crash with "Error setting terminal echo mode (errno 87)".
  The wizard now sets the Windows console input mode directly (adds the `ffi`
  dependency). If raw keyboard input is not available it falls back to numbered
  questions instead of failing. Verified in a real Windows console.

## 0.3.0

- New setup wizard: `dart run adaptable_remote_config`. Arrow-key questions
  (source, force/optional, platforms, key names), then it writes
  `lib/app_update.dart`, wraps `MaterialApp` in `UpdateGate`, initializes
  Firebase in `main()`, adds `firebase_core`, and prints the console parameters
  or the JSON to host. Edits are previewed and confirmed, are skipped when the
  file is not safe to change, and are idempotent.
- `--yes` runs it with no questions; `--source`, `--mode`, `--url`, `--dir` and
  `--out` set answers from the command line.
- No change to the runtime API.

## 0.2.1

- README: pub.dev install instructions, a complete Firebase and HTTP quick
  start, and the Remote Config parameters to create. No code changes.

## 0.2.0

A simplification. Providers now return a plain key/value map and everything
else reads from it, so there is no per-source mapping layer any more.

Breaking:

- `RemoteConfiguration`, `PlatformUpdateConfig`, `PlatformKeyMapping`,
  `ConfigKeyMapping` and `RemoteSetting` are replaced by `RemoteValues` (typed
  getters over any key or dotted path) and `UpdateKeys` (which keys drive the
  update decision, with a `{platform}` placeholder).
- `RemoteConfigProvider.fetch()` returns `Map<String, dynamic>`.
  `FirebaseConfigProvider` no longer takes a mapping; `HttpConfigProvider`
  takes `root` instead of `mapping` / `responseMapper`.
- `RemoteConfigController`: `configuration` -> `values`, `installedAppLoader`
  -> `appInfo`, `platformDetector` -> `platform` (`'android'` / `'ios'`),
  `updateAction` -> `openStore`. `environment`, `policy`,
  `destinationValidator` and the `onCheck` / `onDismiss` / `onUpdateResult`
  callbacks are removed.
- `UpdateBanner`, `UpdateAvailable` and `UpdateLaunchError` are removed; build
  them from the controller with `ListenableBuilder` if needed.
- Cache entries are stored under a new `v2` key; the first launch refetches.

Behavior changes:

- A store link is only validated when an update is actually offered.
- The gate no longer re-shows a postponed prompt on a timer; it does so on the
  next resume or refresh.
- A blank build number no longer produces an invalid `1.0.0+` version.

## 0.1.0

- Initial release: Firebase, HTTP and custom providers, typed settings,
  required/optional update gates, caching, reminders and skipping.
