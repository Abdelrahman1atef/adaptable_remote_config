import 'package:adaptable_remote_config/adaptable_remote_config.dart';
import 'package:flutter/material.dart';

// Copy any of these into your own app. Each one shows one level of
// "Change the look" from the README.

/// Level 2, `iconBuilder`: any widget as the icon (here a gradient badge).
/// [size] is the space the layout gives it: 64 on the dialog, 96 on the wall.
Widget demoIconBuilder(BuildContext context, double size) => Container(
  width: size,
  height: size,
  decoration: const BoxDecoration(
    shape: BoxShape.circle,
    gradient: LinearGradient(colors: [Color(0xFFFF8A65), Color(0xFFE91E63)]),
  ),
  child: Icon(Icons.cake, size: size / 2, color: Colors.white),
);

/// Level 3, `cardBuilder`: your own layout from ready-made parts. The buttons
/// in [data] already work. `data.isRequired` tells the wall from the dialog.
Widget customCard(BuildContext context, UpdateCardData data) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    constraints: const BoxConstraints(maxWidth: 420),
    padding: const EdgeInsetsDirectional.all(20),
    decoration: BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: data.isRequired ? scheme.error : scheme.primary,
        width: 2,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                data.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            data.icon,
          ],
        ),
        const SizedBox(height: 8),
        Text(data.message),
        data.error,
        const SizedBox(height: 16),
        data.updateButton,
        // Only on the dialog; both are null on the wall.
        if (data.laterButton != null) data.laterButton!,
        if (data.skipButton != null) data.skipButton!,
      ],
    ),
  );
}

/// Level 3 again: keep the default card and add something around it.
Widget bannerCard(BuildContext context, UpdateCardData data) => Banner(
  message: data.isRequired ? 'MUST' : 'NEW',
  location: BannerLocation.topEnd,
  color: data.isRequired ? Colors.red : Colors.green,
  child: UpdateCard.fromData(data),
);

/// Level 4, `requiredBuilder`: draw the whole wall yourself. You only need the
/// controller: `controller.openUpdate` is the Update button.
Widget ownWall(BuildContext context, RemoteConfigController controller) {
  return Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF512DA8), Color(0xFFD81B60)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsetsDirectional.all(32),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.rocket_launch, size: 80, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'A new version is waiting',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version ${controller.update.version} is required.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF512DA8),
              ),
              onPressed: controller.isOpeningUpdate
                  ? null
                  : controller.openUpdate,
              child: Text(
                controller.actionError == null ? 'Get it now' : 'Try again',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Level 4, `optionalBuilder`: your own "update available" box.
Widget ownDialog(BuildContext context, RemoteConfigController controller) {
  return Padding(
    padding: const EdgeInsets.all(24),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Version ${controller.update.version} is out',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: controller.dismissOptional,
                  child: const Text('Not now'),
                ),
                FilledButton(
                  onPressed: controller.openUpdate,
                  child: const Text('Update'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
