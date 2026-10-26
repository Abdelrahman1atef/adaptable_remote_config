/// Where the remote values come from.
enum ConfigSource { firebase, http, custom }

/// Which kinds of update the app supports.
enum UpdateMode { both, forceOnly, optionalOnly }

/// How the remote keys are named.
enum KeyStyle { standard, prefixed, nested }

/// One remote value the user has to create (a Firebase parameter or a JSON
/// field).
class ParamSpec {
  const ParamSpec(this.name, this.type, this.example, this.meaning);

  final String name;

  /// `String` or `Boolean`.
  final String type;
  final String example;
  final String meaning;
}

/// Key templates; `{platform}` becomes `android` or `ios`.
class KeyNames {
  const KeyNames({
    required this.minimum,
    required this.latest,
    required this.store,
    required this.force,
  });

  final String minimum;
  final String latest;
  final String store;
  final String force;

  static String _fill(String template, String platform) =>
      template.replaceAll('{platform}', platform);

  String minimumFor(String platform) => _fill(minimum, platform);
  String latestFor(String platform) => _fill(latest, platform);
  String storeFor(String platform) => _fill(store, platform);
  String forceFor(String platform) => _fill(force, platform);
}

/// Everything the wizard collects.
class SetupAnswers {
  const SetupAnswers({
    required this.appId,
    required this.source,
    required this.mode,
    required this.android,
    required this.ios,
    this.keyStyle = KeyStyle.standard,
    this.prefix = '',
    this.httpUrl = '',
    this.androidStoreUrl = '',
    this.iosStoreUrl = '',
    this.outputPath = 'lib/app_update.dart',
    this.group = '',
  });

  final String appId;
  final ConfigSource source;
  final UpdateMode mode;
  final bool android;
  final bool ios;
  final KeyStyle keyStyle;
  final String prefix;
  final String httpUrl;
  final String androidStoreUrl;
  final String iosStoreUrl;
  final String outputPath;

  /// Firebase console folder (parameter group) for the keys; empty for none.
  final String group;

  List<String> get platforms => [if (android) 'android', if (ios) 'ios'];

  bool get usesForce => mode != UpdateMode.optionalOnly;
  bool get usesOptional => mode != UpdateMode.forceOnly;

  KeyNames get keys => switch (keyStyle) {
    KeyStyle.standard => const KeyNames(
      minimum: '{platform}_version',
      latest: '{platform}_latest_version',
      store: '{platform}_store_link',
      force: 'force_update',
    ),
    KeyStyle.prefixed => KeyNames(
      minimum: '${prefix}_{platform}_version',
      latest: '${prefix}_{platform}_latest_version',
      store: '${prefix}_{platform}_store_link',
      force: '${prefix}_force_update',
    ),
    KeyStyle.nested => const KeyNames(
      minimum: '{platform}.minimum_version',
      latest: '{platform}.latest_version',
      store: '{platform}.store_url',
      force: '{platform}.force_update',
    ),
  };

  String storeUrlFor(String platform) =>
      platform == 'android' ? androidStoreUrl : iosStoreUrl;

  /// The values to create, without duplicates (`force_update` is shared).
  List<ParamSpec> get parameters {
    final specs = <ParamSpec>[];
    void add(ParamSpec spec) {
      if (specs.every((s) => s.name != spec.name)) specs.add(spec);
    }

    for (final platform in platforms) {
      if (usesForce) {
        add(
          ParamSpec(
            keys.minimumFor(platform),
            'String',
            '1.0.0+1',
            'Lowest version allowed to run',
          ),
        );
        add(
          ParamSpec(
            keys.forceFor(platform),
            'Boolean',
            'false',
            'true turns the minimum into a blocking update',
          ),
        );
      }
      if (usesOptional) {
        add(
          ParamSpec(
            keys.latestFor(platform),
            'String',
            '1.0.0+1',
            'Newest version; older builds get a dismissible prompt',
          ),
        );
      }
      add(
        ParamSpec(
          keys.storeFor(platform),
          'String',
          storeUrlFor(platform),
          platform == 'android'
            ? 'Play Store link (blank: derived from the package name)'
            : 'App Store link (required for iOS updates)',
        ),
      );
    }
    return specs;
  }
}
