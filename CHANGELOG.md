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
