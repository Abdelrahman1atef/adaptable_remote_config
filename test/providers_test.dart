import 'dart:convert';

import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeFirebase extends Fake implements FirebaseRemoteConfig {
  final calls = <String>[];

  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) async {}

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async =>
      calls.add('defaults');

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<bool> fetchAndActivate() async {
    calls.add('fetchAndActivate');
    return true;
  }

  @override
  Map<String, RemoteConfigValue> getAll() => {
    'android_version': RemoteConfigValue(
      utf8.encode('2'),
      ValueSource.valueRemote,
    ),
  };
}

void main() {
  test('Firebase returns every key as a string map', () async {
    final firebase = FakeFirebase();
    final provider = FirebaseConfigProvider(
      remoteConfig: firebase,
      defaults: const {'a': 'b'},
    );
    expect(await provider.fetch(), {'android_version': '2'});
    expect(firebase.calls, ['defaults', 'fetchAndActivate']);
  });

  test('HTTP reads the object at root and rejects bad responses', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/ok') {
        return http.Response(
          jsonEncode({
            'data': {
              'app': {'android_version': '2'},
            },
          }),
          200,
        );
      }
      if (request.url.path == '/list') return http.Response('[]', 200);
      return http.Response('nope', 500);
    });
    Uri url(String path) => Uri.parse('https://config.example$path');

    final ok = HttpConfigProvider(
      url: url('/ok'),
      root: 'data.app',
      client: client,
    );
    expect(await ok.fetch(), {'android_version': '2'});
    expect(
      HttpConfigProvider(url: url('/list'), client: client).fetch(),
      throwsFormatException,
    );
    expect(
      HttpConfigProvider(url: url('/x'), client: client).fetch(),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('Custom forwards fetch and dispose', () async {
    var disposed = false;
    final provider = CustomConfigProvider(
      () async => {'a': 1},
      onDispose: () async => disposed = true,
    );
    expect(await provider.fetch(), {'a': 1});
    await provider.dispose();
    expect(disposed, true);
  });
}
