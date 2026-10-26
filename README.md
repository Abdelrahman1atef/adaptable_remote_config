# adaptable_remote_config

[![pub package](https://img.shields.io/pub/v/adaptable_remote_config.svg)](https://pub.dev/packages/adaptable_remote_config)

Tell old versions of your app to update, **without releasing a new app**.

- **Force update:** old versions see a full-screen wall. They must update to continue.
- **Optional update:** old versions see a small dialog. They can tap *Later* or *Skip*.

You change a few values on a server. The app reads them and decides what to show.
Works on Android and iOS.

---

## How it works (60 seconds)

```
 1. YOU change a value          "minimum version is now 2.0.0"
        │                        (in Firebase, in a JSON file, or in your own code)
        ▼
 2. The app reads it            when it starts, and again when it comes back
        │                        to the screen after about an hour
        ▼
 3. The app compares            installed version  vs  the version you set
        │
        ▼
 4. It decides                  fine  →  nothing happens
                                a bit old  →  optional dialog
                                too old  →  force-update wall
```

Three things are involved:

| Piece | What it is |
| --- | --- |
| **Source** | Where your values live. You pick one (see below). |
| **Controller** | Reads the values and decides. You create one. |
| **UpdateGate** | A widget around your app. It shows the wall or dialog. |

If the app cannot reach the source (no internet), it uses the last values it saved.
If there is nothing saved, it lets the user in. **It never blocks users by mistake.**

---

## Step 0: Pick your method

| Method | Choose it if... | Needs |
| --- | --- | --- |
| **1. Firebase** | You already use Firebase, or you want the easiest way to edit values. | A Firebase project |
| **2. A JSON file** | You do not use Firebase. You can put a small file on any website. | A place to host a file |
| **3. Your own code** | You already have a backend API with app settings. | An API that returns settings |

Not sure? Choose **Firebase**.

---

## The fast way: let the setup tool do it

Run these two commands in your Flutter app folder:

```sh
flutter pub add adaptable_remote_config
dart run adaptable_remote_config
```

The tool asks a few questions. Use the **arrow keys**, **space** and **Enter**.
Then it:

1. Writes `lib/app_update.dart` (the controller).
2. Wraps your `MaterialApp` with `UpdateGate`.
3. For Firebase: starts Firebase in `main()`, and adds `firebase_core` if missing.
4. For Firebase: creates the values in your Firebase project (it shows them first and asks).
   If you give the app a **prefix**, it puts the values in their own **folder** in the
   Firebase console (see *Two apps in one Firebase project* below).

It never changes a value that already exists. If it cannot edit a file safely, it
leaves the file alone and shows you the few lines to add yourself.

**No questions at all:**

```sh
dart run adaptable_remote_config --yes
```

More options:

| Option | What it does |
| --- | --- |
| `--source firebase` (or `http`, `custom`) | Choose the method without being asked |
| `--mode both` (or `force`, `optional`) | Choose the update types without being asked |
| `--url https://...` | The JSON file address (for `http`) |
| `--publish` | Create the Firebase values without asking |
| `--no-publish` | Do not touch Firebase, only print the values to create |
| `--prefix customer` | Several apps in one Firebase project: name the keys `customer_android_version`... (see below) |
| `--group "Customer app"` | Put the keys in this Firebase console folder (default: the prefix) |
| `--no-group` | Do not use a console folder |
| `--project my-project-id` | Choose the Firebase project |
| `--dir path` / `--out path` | Choose the app folder / the file to write |

With `--yes`, nothing is written to your Firebase project unless you add `--publish`.

Prefer to do it yourself? Follow your method below.

---

# Method 1: Firebase

## What you need

- A Flutter app connected to Firebase (`flutterfire configure` done once).
- The packages `firebase_core` and `adaptable_remote_config`.

## How it works

Firebase Remote Config stores a list of named values (like `android_version`).
You edit them in the Firebase website. The app downloads them. No app release needed.

## Steps

**1. Add the packages**

```sh
flutter pub add adaptable_remote_config firebase_core
```

**2. Connect your app to Firebase (once)**

```sh
dart pub global activate flutterfire_cli
flutterfire configure
```

This creates `lib/firebase_options.dart`.

**3. Start Firebase in `main()`**

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}
```

**4. Create `lib/app_update.dart`**

```dart
import 'package:adaptable_remote_config/adaptable_remote_config.dart';

class AppUpdate {
  AppUpdate._();

  static final RemoteConfigController controller = RemoteConfigController(
    appId: 'my_app', // any name; it labels the saved copy on the phone
    provider: FirebaseConfigProvider(
      // The values used when Firebase has nothing yet. These change nothing.
      defaults: const {
        'android_version': '1.0.0+1',
        'ios_version': '1.0.0+1',
        'force_update': false,
        'android_latest_version': '1.0.0+1',
        'ios_latest_version': '1.0.0+1',
        'android_store_link': '',
        'ios_store_link': '',
      },
    ),
    subscribeToChanges: true,
  );
}
```

**5. Wrap your app with `UpdateGate`**

```dart
MaterialApp(
  builder: (context, child) => UpdateGate(
    controller: AppUpdate.controller,
    child: child!,
  ),
  // ...
)
```

(Use the same `builder:` on `MaterialApp.router`.) If you already have a `builder:`,
call `UpdateGate(...)` inside it, around the widget it returns.

**6. Create the values in Firebase**

Firebase console → **Remote Config** → **Add parameter**. Create these:

| Name | Type | Start with | Meaning |
| --- | --- | --- | --- |
| `android_version` | String | `1.0.0+1` | Oldest Android version allowed |
| `ios_version` | String | `1.0.0+1` | Oldest iOS version allowed |
| `force_update` | Boolean | `false` | `true` turns on the force-update wall |
| `android_latest_version` | String | `1.0.0+1` | Newest Android version (for the optional dialog) |
| `ios_latest_version` | String | `1.0.0+1` | Newest iOS version |
| `android_store_link` | String | *(empty)* | Play Store link. Empty = the app finds it itself |
| `ios_store_link` | String | *(empty)* | App Store link. **Required for iOS** |

Press **Publish changes**. (The setup tool can create all of these for you.)

**7. Run the app.** Nothing should change yet. That is correct.

## Test it

| I want to... | Set this in Firebase, then Publish changes |
| --- | --- |
| See the **optional dialog** | `android_latest_version` = a number **higher** than your installed version, e.g. `9.0.0+1` |
| See the **force wall** | `android_version` = `9.0.0+1` **and** `force_update` = `true` |
| Go back to normal | Put the old values back (`1.0.0+1` and `false`) and publish |

Then **close the app fully and open it again**. Users get the change the next time they
start the app, usually within an hour (Firebase keeps a copy for up to an hour).

> **Careful:** Firebase has no test mode. A force-update value reaches **all** your
> users. Test with the *optional* dialog first.

## Two apps in one Firebase project? Give each app a prefix

Many teams use **one** Firebase project for several apps (for example a *customer* app
and a *driver* app). They would all read the same names, such as `android_version`, and
change each other. A **prefix** fixes this: each app gets its own names, and its own
**folder** in the Firebase console.

```
Firebase console → Remote Config
 ├── 📁 customer          ← customer app
 │     customer_android_version
 │     customer_ios_version
 │     customer_force_update
 │     ...
 └── 📁 driver            ← driver app
       driver_android_version
       driver_ios_version
       driver_force_update
       ...
```

**The easy way.** In each app, run the setup tool with its own prefix:

```sh
dart run adaptable_remote_config --prefix customer     # in the customer app
dart run adaptable_remote_config --prefix driver       # in the driver app
```

It creates the keys with that prefix **inside a folder with the same name**. (You can
also answer the questions: choose *With a prefix*, then type the prefix and the folder.)
Keys that already exist are never changed.

**By hand.** Do this for each app:

1. Choose a short prefix: lowercase letters, digits and `_` only (`customer`, `driver`).
2. In `lib/app_update.dart`, tell the controller the prefix, and use the prefixed names
   in `defaults`:

   ```dart
   static final RemoteConfigController controller = RemoteConfigController(
     appId: 'customer',
     keys: const UpdateKeys.prefixed('customer'),
     provider: FirebaseConfigProvider(
       defaults: const {
         'customer_android_version': '1.0.0+1',
         'customer_ios_version': '1.0.0+1',
         'customer_force_update': false,
         'customer_android_latest_version': '1.0.0+1',
         'customer_ios_latest_version': '1.0.0+1',
         'customer_android_store_link': '',
         'customer_ios_store_link': '',
       },
     ),
     subscribeToChanges: true,
   );
   ```

3. In the Firebase console, open **Remote Config**, choose **Add new → Parameter group**,
   and name it `customer`.
4. Add the seven keys above to that group (same types as in step 6), then
   **Publish changes**.

Each app now only reads its own keys, so changing the driver app never touches the
customer app.

---

# Method 2: A JSON file

## What you need

- A small text file on any website (your server, GitHub Pages, Firebase Hosting...).
- The address must start with `https://`.

## How it works

The app downloads your file when it starts. You edit the file to change the values.

## Steps

**1. Add the package**

```sh
flutter pub add adaptable_remote_config
```

**2. Create the file** (for example `app_config.json`) and upload it:

```json
{
  "android": {
    "minimum_version": "1.0.0+1",
    "latest_version": "1.0.0+1",
    "force_update": false,
    "store_url": "https://play.google.com/store/apps/details?id=com.example.app"
  },
  "ios": {
    "minimum_version": "1.0.0+1",
    "latest_version": "1.0.0+1",
    "force_update": false,
    "store_url": "https://apps.apple.com/app/id1234567890"
  }
}
```

**3. Create `lib/app_update.dart`**

```dart
import 'package:adaptable_remote_config/adaptable_remote_config.dart';

class AppUpdate {
  AppUpdate._();

  static final RemoteConfigController controller = RemoteConfigController(
    appId: 'my_app',
    provider: HttpConfigProvider(
      url: Uri.parse('https://example.com/app_config.json'),
    ),
    keys: const UpdateKeys.nested(), // tells the app your file uses "android": {...}
  );
}
```

If your file is inside another object, for example `{"data": {"app": {...}}}`,
add `root: 'data.app'` to `HttpConfigProvider`.

**4. Wrap your app with `UpdateGate`** (same as Firebase, step 5):

```dart
MaterialApp(
  builder: (context, child) => UpdateGate(
    controller: AppUpdate.controller,
    child: child!,
  ),
)
```

**5. Run the app.** Nothing should change yet.

## Test it

Edit the file on your server:

- **Optional dialog:** set `latest_version` to `9.0.0+1`.
- **Force wall:** set `minimum_version` to `9.0.0+1` and `force_update` to `true`.
- **Back to normal:** put `1.0.0+1` and `false` again.

Close the app fully and open it again. Make sure your server does not cache the file
for a long time.

---

# Method 3: Your own code

## What you need

- Any code that returns your settings as a map: your own API, a database, anything.

## How it works

You give the controller a function. The app calls it when it starts. The function
returns the values. You decide where they come from.

## Steps

**1. Add the package**

```sh
flutter pub add adaptable_remote_config
```

**2. Create `lib/app_update.dart`**

```dart
import 'package:adaptable_remote_config/adaptable_remote_config.dart';

class AppUpdate {
  AppUpdate._();

  static final RemoteConfigController controller = RemoteConfigController(
    appId: 'my_app',
    provider: CustomConfigProvider(() async {
      final settings = await myApi.getAppSettings(); // your own call
      return {
        'android_version': settings.minAndroid, // e.g. '2.0.0+1'
        'ios_version': settings.minIos,
        'force_update': settings.forceUpdate,   // true or false
        'android_latest_version': settings.latestAndroid,
        'ios_latest_version': settings.latestIos,
        'ios_store_link': settings.iosStoreUrl,
      };
    }),
  );
}
```

The function must **return a map** (or throw an error if it fails; the app then uses
the saved values). These names are the default names. You can use your own names, see
*Use your own key names* below.

**3. Wrap your app with `UpdateGate`** (same as the other methods).

**4. Run the app.** Nothing should change yet.

## Test it

Make your API return a higher `android_version` with `force_update: true`, or a higher
`android_latest_version`. Close the app and open it again.

---

# Good to know

## What the user sees

| Your values | Installed app | The user sees |
| --- | --- | --- |
| `force_update` = true, minimum version is **higher** than installed | too old | **Wall.** Cannot continue. Only an *Update* button. |
| Latest version is **higher** than installed | a bit old | **Dialog** with *Update*, *Later*, *Skip this version* |
| Installed is equal or newer | up to date | Nothing |

- *Later* hides the dialog for one day. *Skip this version* hides it for that version only.
- The wall can never be dismissed.
- The *Update* button opens the store link. On Android, an empty link is fine: the app
  builds the Play Store link from your package name. On iOS you **must** set a link.

## Version format

Write versions like `1.2.0` or `1.2.0+4` (name, then `+` and the build number).
These are the same numbers as `version: 1.2.0+4` in your `pubspec.yaml`.
Letters like `1.2.0-beta` are not allowed.

If you type a wrong version, the app **ignores the bad update and keeps the last good
values**. It never blocks users because of a typo.

## Use your own key names

Your values can have other names. Tell the controller with `keys:`

```dart
keys: const UpdateKeys.prefixed('shop'),   // shop_android_version, shop_force_update, ...
keys: const UpdateKeys.nested(),           // {"android": {"minimum_version": ...}}
keys: const UpdateKeys(                    // anything you like
  minimumVersion: 'min_{platform}',        // {platform} becomes android or ios
  latestVersion: 'new_{platform}',
  storeUrl: 'link_{platform}',
  forceUpdate: 'must_update',
),
```

`UpdateKeys.prefixed('shop')` is useful when two apps share one Firebase project.

## Read other settings too

The same values can hold your own settings (a feature switch, an API address...):

```dart
final values = AppUpdate.controller.values;
values.string('base_url', 'https://fallback.example.com'); // text
values.boolean('new_checkout');                            // true / false
values.number('request_limit', 10);                        // number
```

If the value is missing or wrong, you get the fallback you gave. Do not read these
before `await AppUpdate.controller.initialize()` finishes.

## Change the look

```dart
UpdateGate(
  controller: AppUpdate.controller,
  loadingBuilder: (context) => const MySplash(),
  requiredBuilder: (context, controller) => MyWall(controller: controller),
  optionalBuilder: (context, controller) => MyDialog(controller: controller),
  texts: const UpdateTexts(update: 'Get it now'), // Arabic text is automatic for `ar`
  showOptional: true,   // false = never show the optional dialog
  allowSkip: true,      // false = hide the "Skip this version" button
)
```

Your own wall only needs one button:

```dart
ListenableBuilder(
  listenable: controller,
  builder: (_, _) => FilledButton(
    onPressed: controller.isOpeningUpdate ? null : controller.openUpdate,
    child: Text(controller.actionError == null ? 'Update' : 'Try again'),
  ),
)
```

---

# Problems?

| What you see | What to check |
| --- | --- |
| **Nothing shows** after I changed a value | 1. Did you press **Publish changes** (Firebase)? 2. Is your number **higher** than the installed version? 3. For the wall: is `force_update` **true**? 4. Close the app fully and open it again. |
| **Firebase says it is not initialized** | `Firebase.initializeApp(...)` must run **before** the app first uses `AppUpdate.controller`. Put it first in `main()`. |
| **The Update button does nothing** | Check the store link. On iOS it is required. It must start with `https://`. |
| **The wall shows for everyone** | The minimum version is higher than the installed one. Put the old value back and publish. |
| **Changes arrive slowly (Firebase)** | Firebase keeps a copy for up to one hour on release apps. Wait, or restart the app after an hour. |
| **The setup tool does not move with arrow keys** | Update to the latest version of this package. If it still fails, type the number of your choice, or use `--yes`. |
| **`dart run adaptable_remote_config` says the package is missing** | Run `flutter pub add adaptable_remote_config` first, from the app folder. |

---

# For developers

**Controller methods:** `initialize()` (wait for the first check, at most 4 seconds),
`refresh({force})` (ask the source again), `check()` (decide again, no network),
`openUpdate()` (open the store), `dismissOptional({skipVersion})` (*Later* / *Skip*).

**Controller values you can watch** (it is a `ChangeNotifier`): `values`, `update`,
`shouldPrompt`, `isReady`, `error`, `actionError`.

**Controller options:** `appId`, `provider`, `keys`, `defaults`, `storage`, `comparator`,
`openStore`, `startupWait`, `requestTimeout`, `refreshInterval`, `remindAfter`,
`subscribeToChanges`, `onError`.

**Sources:** `FirebaseConfigProvider`, `HttpConfigProvider`, `CustomConfigProvider`.
Make your own by extending `RemoteConfigProvider` (one method: `fetch()`).

**Building blocks:** `UpdateGate`, `RequiredUpdatePage`, `OptionalUpdateDialog`,
`UpdateButton`, `UpdateTexts`.

**Run the checks:**

```sh
flutter pub get
flutter analyze
flutter test
```

Issues and pull requests are welcome at
[github.com/Abdelrahman1atef/adaptable_remote_config](https://github.com/Abdelrahman1atef/adaptable_remote_config).

## License

MIT. See [LICENSE](LICENSE).
