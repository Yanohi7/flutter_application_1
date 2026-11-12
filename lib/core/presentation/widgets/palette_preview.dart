import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import 'wallpaper.dart';

/// Shows the actual background artwork rather than an unrelated inner dot.
class PalettePreview extends StatelessWidget {
  const PalettePreview({super.key, required this.palette, this.height = 48});
  final AppPalette palette;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: height,
      child: ClipOval(
        child: Theme(
          data: AppTheme.build(Theme.of(context).brightness, palette: palette),
          child: ThemeWallpaper(style: palette.backgroundStyle, preview: true),
        ),
      ),
    ),
  );
}
