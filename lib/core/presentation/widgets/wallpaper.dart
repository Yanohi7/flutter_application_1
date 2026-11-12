import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Restores the original full-screen palette backgrounds and decorative patterns.
class ThemeWallpaper extends StatelessWidget {
  const ThemeWallpaper({super.key, required this.style, this.preview = false});
  final String style;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pairs = <String, List<Color>>{
      'blue': [const Color(0xFFE1EAF8), const Color(0xFF1A2940)],
      'green': [const Color(0xFFE0EFE7), const Color(0xFF1B3028)],
      'purple': [const Color(0xFFEFE3F4), const Color(0xFF30243D)],
      'slate': [const Color(0xFFE4ECF5), const Color(0xFF1E2B3A)],
      'sage': [const Color(0xFFE7EEE7), const Color(0xFF202F29)],
      'linen': [const Color(0xFFF3EADD), const Color(0xFF30281F)],
      'ocean': [const Color(0xFFD6F1F3), const Color(0xFF102E45)],
      'geometry': [const Color(0xFFE8E4F5), const Color(0xFF29213E)],
      'dusk': [const Color(0xFFF2DFE8), const Color(0xFF302341)],
      'forest': [const Color(0xFFDDECE4), const Color(0xFF13372F)],
      'rose': [const Color(0xFFF4E0E4), const Color(0xFF3C2532)],
    };
    final backdrop =
        pairs[style]?[isDark ? 1 : 0] ??
        Theme.of(context).colorScheme.surfaceContainerLow;
    final base = preview
        ? Color.lerp(backdrop, Theme.of(context).colorScheme.primary, 0.28)!
        : backdrop;
    final decorated = [
      'ocean',
      'geometry',
      'dusk',
      'forest',
      'rose',
    ].contains(style);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        gradient: decorated
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base,
                  Color.lerp(
                    base,
                    isDark ? const Color(0xFF101A30) : const Color(0xFFF5E5CC),
                    0.65,
                  )!,
                ],
              )
            : null,
      ),
      child: CustomPaint(
        painter: _Pattern(style, isDark, preview),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Pattern extends CustomPainter {
  const _Pattern(this.style, this.isDark, this.preview);
  final String style;
  final bool isDark;
  final bool preview;

  @override
  void paint(Canvas canvas, Size size) {
    if (!['ocean', 'geometry', 'dusk', 'forest', 'rose'].contains(style))
      return;
    final paint = Paint()
      ..color = Colors.white.withValues(
        alpha: preview
            ? 0.48
            : isDark
            ? 0.045
            : 0.28,
      );
    for (var i = 0; i < 9; i++) {
      final x = ((i * 37 + 13) % 100) / 100 * size.width;
      final y = ((i * 23 + 7) % 100) / 100 * size.height;
      final r = math.min(size.width, size.height) * (0.06 + (i % 3) * 0.045);
      if (style == 'geometry') {
        canvas.drawPath(
          Path()
            ..moveTo(x, y - r)
            ..lineTo(x + r, y)
            ..lineTo(x, y + r)
            ..lineTo(x - r, y)
            ..close(),
          paint,
        );
      } else if (style == 'ocean') {
        canvas.drawCircle(Offset(x, y), r, paint);
        canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.16)
            ..style = PaintingStyle.stroke,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: r * 5, height: r * 2),
          paint
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              math.min(size.width, size.height) * 0.09,
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Pattern old) =>
      old.style != style || old.isDark != isDark || old.preview != preview;
}

class PhotoWallpaper extends StatefulWidget {
  const PhotoWallpaper({
    super.key,
    required this.path,
    this.x = 0,
    this.y = 0,
    this.zoom = 1,
    this.opacity = 1,
  });
  final String path;
  final double x, y, zoom;
  final double opacity;

  @override
  State<PhotoWallpaper> createState() => _PhotoWallpaperState();
}

class _PhotoWallpaperState extends State<PhotoWallpaper> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageProvider? _image;
  Size? _size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream == null) _resolve();
  }

  @override
  void didUpdateWidget(PhotoWallpaper old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _resolve();
  }

  void _resolve() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _size = null;
    // A wallpaper only needs screen-sized pixels, even when a camera photo is large.
    _image = ResizeImage(
      FileImage(File(widget.path)),
      width: 2560,
      height: 2560,
      policy: ResizeImagePolicy.fit,
    );
    _stream = _image!.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener((info, _) {
      if (mounted)
        setState(
          () => _size = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          ),
        );
      info.dispose();
    }, onError: (Object _, StackTrace? _) {});
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = _size;
      if (size == null) return const SizedBox.expand();
      final scale =
          math.max(
            constraints.maxWidth / size.width,
            constraints.maxHeight / size.height,
          ) *
          widget.zoom;
      final width = size.width * scale, height = size.height * scale;
      return ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: (constraints.maxWidth - width) * (widget.x + 1) / 2,
              top: (constraints.maxHeight - height) * (widget.y + 1) / 2,
              width: width,
              height: height,
              child: Image(
                image: _image!,
                fit: BoxFit.fill,
                opacity: AlwaysStoppedAnimation(widget.opacity),
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      );
    },
  );
}
