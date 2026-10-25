import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter/material.dart';

/// Change the map below to try none, optional or required updates. Swap the
/// provider for `FirebaseConfigProvider()` or `HttpConfigProvider(url: …)` in
/// a real app; nothing else changes.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final updates = RemoteConfigController(
    appId: 'example',
    provider: CustomConfigProvider(
      () async => {
        'android_latest_version': '2.0.0',
        'android_store_link':
            'https://play.google.com/store/apps/details?id=com.example.app',
        'base_url': 'https://api.example.com',
      },
    ),
    // Only needed here, to be independent of the host app's real version.
    appInfo: () async =>
        const AppInfo(version: '1.0.0+1', packageName: 'com.example.app'),
    platform: 'android',
  );
  runApp(ExampleApp(updates: updates));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, required this.updates});

  final RemoteConfigController updates;

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (_, child) => UpdateGate(controller: updates, child: child!),
    home: Scaffold(
      appBar: AppBar(title: const Text('Remote config example')),
      body: ListenableBuilder(
        listenable: updates,
        builder: (_, _) => ListView(
          children: [
            ListTile(
              title: const Text('API base URL'),
              subtitle: Text(updates.values.string('base_url', 'fallback')),
            ),
            ListTile(
              title: const Text('Refresh'),
              onTap: () => updates.refresh(),
            ),
          ],
        ),
      ),
    ),
  );
}
