import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_palette.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Wallpaper surfaces keep normal text readable at minimum opacity', () {
    for (final palette in AppPalette.presets) {
      for (final brightness in Brightness.values) {
        final theme = AppTheme.build(
          brightness,
          palette: palette,
          surfaceOpacity: 0.25,
        );
        final scheme = theme.colorScheme;
        for (final backdrop in [Colors.black, Colors.white]) {
          for (final (name, surface) in [
            ('entry header', scheme.surface),
            ('card', Color.alphaBlend(theme.cardTheme.color!, backdrop)),
            (
              'app bar',
              Color.alphaBlend(theme.appBarTheme.backgroundColor!, backdrop),
            ),
          ]) {
            for (final foreground in [
              scheme.onSurface,
              scheme.onSurfaceVariant,
              scheme.primary,
            ]) {
              expect(
                _contrast(foreground, surface),
                greaterThanOrEqualTo(4.5),
                reason: '${palette.name}, ${brightness.name}, $name',
              );
            }
          }
        }
      }
    }
  });
}

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}
