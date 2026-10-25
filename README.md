# adaptable_remote_config

Remote settings and app-update gating for Flutter, built on one idea:

> A **provider** returns key/value pairs. **`UpdateKeys`** says which keys mean
> "minimum version", "latest version", "store link" and "force". The
> **controller** turns that into a decision, and **`UpdateGate`** shows it.

The same code works with Firebase Remote Config, an HTTP JSON file, or any
function that returns a map. There is no dependency on Bloc, Provider, GetIt or
a router. Supports Android and iOS.

## Setup (three steps)

```yaml
dependencies:
  adaptable_remote_config:
    path: packages/adaptable_remote_config
```

```dart
// 1. A controller: a source + an id for the cache.
final updates = RemoteConfigController(
  appId: 'my_app',
  provider: FirebaseConfigProvider(),            // initialize Firebase first
);

// 2. Wrap the app. Put it in the builder, above every route.
MaterialApp.router(
  builder: (context, child) => UpdateGate(controller: updates, child: child!),
);

// 3. Dispose it when its owner ends.
updates.dispose();
```

That's all for the default keys (`android_version`, `ios_version`,
`android_store_link`, `ios_store_link`, `force_update`, and optionally
`android_latest_version`, `ios_latest_version`).

## Choose where the values come from

| Provider | Use |
| --- | --- |
| `FirebaseConfigProvider()` | Firebase Remote Config. Pass `defaults:` for every key the app reads. |
| `HttpConfigProvider(url: …)` | A JSON object. `root: 'data.app'` if the response wraps it. Also `method`, `headers`, `body`, `client`. |
| `CustomConfigProvider(() async => map)` | Anything else: an existing API client, a database… |

Subclass `RemoteConfigProvider` for more. Providers just throw on failure; the
controller falls back to its cache. Each event on `provider.changes` triggers a
refetch when `subscribeToChanges: true` (Firebase real-time updates use this).

## Choose the key names

`UpdateKeys` values are keys or dotted paths. `{platform}` becomes `android` or
`ios`.

```dart
const UpdateKeys()                       // android_version, ios_version, force_update, …
const UpdateKeys.prefixed('shop')        // shop_android_version, shop_force_update, …
const UpdateKeys.nested()                // {"android": {"minimum_version": …}} JSON
const UpdateKeys(                        // anything
  minimumVersion: 'min.{platform}',
  forceUpdate: 'must_update',
  storeUrl: 'links.{platform}',
)
```

Pass it as `RemoteConfigController(keys: …)`.

## Read other settings (feature flags, base URL…)

Every key in the snapshot is available, not only the update ones:

```dart
final values = updates.values;                   // defaults + last good snapshot
values.string('base_url', 'https://fallback');   // trimmed, blank -> fallback
values.boolean('new_checkout');                  // true/false/'true'/'1'
values.number('request_limit', 10);
values.json('appearance', {'style': 'default'}); // object, list or JSON string
values.string('theme.mode');                     // dotted path into nested JSON
```

Missing, blank or wrong-type values return the fallback. Local `defaults:` on the
controller sit underneath the remote values. The controller notifies listeners
when the snapshot changes, so `ListenableBuilder(listenable: updates, …)`
rebuilds on new settings. Keep the config endpoint separate from your API
`base_url`, and call `await updates.initialize()` before creating the API client.

## How the decision is made

| Result | When | UI |
| --- | --- | --- |
| `required` | `force_update` is true and the installed version is below the minimum | Blocking page |
| `optional` | The installed version is below the latest | Dialog: Update / Later / Skip this version |
| `none` | Otherwise | Your app |

- Versions compare as dotted numbers (missing parts are zero), then `+build`.
  Pass `comparator:` for other formats; it must throw on malformed input.
- A snapshot with malformed versions, a latest below the minimum, or no usable
  store link when an update is offered is **rejected as a whole**; the last
  good snapshot stays in force. With nothing cached, the user is let in.
- Store links accept `https`, `http`, `market://details?id=…` and
  `itms-apps://…`. Android derives the Play Store page from the package name if
  no link is configured; iOS needs one.
- Later hides the prompt for `remindAfter` (one day); Skip hides that version
  for good. Both persist. A required update ignores them.

## Customize the UI

```dart
UpdateGate(
  controller: updates,
  loadingBuilder: (context) => const MySplash(),
  requiredBuilder: (context, controller) => MyWall(controller: controller),
  optionalBuilder: (context, controller) => MyDialog(controller: controller),
  texts: const UpdateTexts(update: 'Get it'),   // Arabic is automatic for `ar`
  showOptional: true, checkOnResume: true, allowSkip: true,
)
```

A custom wall only needs the controller:

```dart
ListenableBuilder(
  listenable: controller,
  builder: (_, _) => FilledButton(
    onPressed: controller.isOpeningUpdate ? null : controller.openUpdate,
    child: Text(controller.actionError == null ? 'Update' : 'Retry'),
  ),
)
```

Building blocks: `RequiredUpdatePage`, `OptionalUpdateDialog`, `UpdateButton`.
While a required update applies the app stays mounted but hidden, without
focus, input or accessibility access, and an isolated navigator keeps back from
reaching it.

## Controller reference

| Member | Meaning |
| --- | --- |
| `initialize()` | Waits for the first check, at most `startupWait` (4 s). |
| `refresh({force})` | Fetches again; `force: false` respects `refreshInterval` (1 h). |
| `check()` | Re-evaluates the current values, no network. |
| `openUpdate()` | Opens the store (`openStore:` replaces the default launcher). |
| `dismissOptional({skipVersion})` | Later / Skip. |
| `values`, `update`, `shouldPrompt`, `isReady`, `error`, `actionError` | Observable state. |
| `onError` | Called for every provider, validation, storage or launch error. |

`appInfo:` and `platform:` can be injected (tests, other environments).
`storage:` swaps the SharedPreferences cache (`MemoryConfigStorage` for tests).

## Tests

```sh
flutter pub get
flutter analyze
flutter test
```

Native Firebase fetches and real store launches need an Android/iOS device
check; the unit tests use fakes.

## License

MIT. See [LICENSE](LICENSE).
