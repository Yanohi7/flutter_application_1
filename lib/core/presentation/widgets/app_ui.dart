// Provide shared field labels, unavailable-action messages

import 'package:flutter/material.dart';

import '../app_preferences.dart';

/// A themed surface for related controls and labels over the app wallpaper.
class ReadablePanel extends StatelessWidget {
  const ReadablePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

/// Keeps standalone text readable on a custom photo at any wallpaper opacity.
class WallpaperTextSurface extends StatelessWidget {
  const WallpaperTextSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (appPreferences.backgroundPath == null) return child;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: child,
      ),
    );
  }
}

// Reuse one label style for settings sections and editor fields
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13,
      ),
    ),
  );
}

void showUnavailable(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('$feature is not available yet')));
}
