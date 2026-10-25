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
