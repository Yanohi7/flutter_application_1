import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_palette.dart';

String paletteLabel(BuildContext context, AppPalette palette) {
  final l10n = AppLocalizations.of(context)!;
  return switch (palette.id) {
    'graphite' => l10n.graphite,
    'blue' => l10n.blue,
    'green' => l10n.green,
    'purple' => l10n.purple,
    'slate' => l10n.slate,
    'sage' => l10n.sage,
    'linen' => l10n.linen,
    'ocean' => l10n.ocean,
    'forest' => l10n.forest,
    'geometry' => l10n.geometry,
    'dusk' => l10n.dusk,
    'rose' => l10n.rose,
    _ => palette.name,
  };
}
