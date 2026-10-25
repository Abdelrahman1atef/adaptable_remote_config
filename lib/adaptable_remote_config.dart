/// Remote settings and app-update gating for Flutter.
///
/// A [RemoteConfigProvider] returns key/value pairs, [UpdateKeys] names the
/// keys that drive the update decision, [RemoteConfigController] holds the
/// result, and [UpdateGate] shows the update UI.
library;

export 'src/controller.dart';
export 'src/providers.dart';
export 'src/storage.dart';
export 'src/update.dart';
export 'src/values.dart';
export 'src/widgets/update_gate.dart';
export 'src/widgets/update_widgets.dart';
