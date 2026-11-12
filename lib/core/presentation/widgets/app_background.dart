import 'package:flutter/material.dart';

import '../app_preferences.dart';
import 'wallpaper.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ThemeWallpaper(style: appPreferences.backgroundStyle),
            if (appPreferences.backgroundPath case final String path)
              PhotoWallpaper(
                path: path,
                x: appPreferences.photoX,
                y: appPreferences.photoY,
                zoom: appPreferences.photoZoom,
                opacity: 1 - appPreferences.backgroundFade,
              ),
          ],
        ),
      ),
      child,
    ],
  );
}
