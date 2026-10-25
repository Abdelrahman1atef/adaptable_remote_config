# Example app

`lib/main.dart` uses a custom in-memory provider and explicit app metadata, so
it needs no Firebase project. It shows an optional update dialog, a remote
`base_url` and a manual refresh. Edit the map in `main.dart` to try other
outcomes (add `android_version` + `force_update: 'true'` for the blocking page).

Generate native scaffolding once and run it:

```sh
flutter create --platforms=android,ios --project-name adaptable_remote_config_example .
flutter pub get
flutter run
```

Keep this directory's `pubspec.yaml` and `lib/` when generating scaffolding.
