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

  static ImageProvider<Object> imageProvider(
    String path,
    BuildContext context,
  ) {
    final screen = MediaQuery.sizeOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    // Leave room to zoom without decoding the original camera image at full size.
    final edge = ((screen.longestSide * pixelRatio * 1.4 / 256).ceil() * 256)
        .clamp(1536, 3840)
        .toInt();
    return ResizeImage(
      FileImage(File(path)),
      width: edge,
      height: edge,
      policy: ResizeImagePolicy.fit,
    );
  }

  static ({Size photo, Offset pan}) crop(
    Size viewport,
    Size source,
    double zoom,
  ) {
    final scale = math.max(
      viewport.width / source.width,
      viewport.height / source.height,
    );
    final photo = source * (scale * zoom);
    final overflowX = math.max(0.0, photo.width - viewport.width);
    final overflowY = math.max(0.0, photo.height - viewport.height);
    // At 100%, center the small crop caused by nearly matching aspect ratios.
    return (
      photo: photo,
      pan: Offset(
        zoom == 1 && overflowX <= viewport.width * 0.04 ? 0 : overflowX,
        zoom == 1 && overflowY <= viewport.height * 0.04 ? 0 : overflowY,
      ),
    );
  }

  @override
  State<PhotoWallpaper> createState() => _PhotoWallpaperState();
}

class _PhotoWallpaperState extends State<PhotoWallpaper> {
  ImageProvider<Object>? _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _frame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(PhotoWallpaper old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _resolve();
  }

  void _resolve() {
    final provider = PhotoWallpaper.imageProvider(widget.path, context);
    if (_provider == provider) return;
    _provider = provider;
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = provider.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted) {
          info.dispose();
          return;
        }
        final old = _frame;
        setState(() => _frame = info);
        old?.dispose();
      },
      onError: (Object _, StackTrace? _) {
        final old = _frame;
        if (mounted) setState(() => _frame = null);
        old?.dispose();
      },
    );
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _frame?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final image = _frame?.image;
      if (image == null) return const SizedBox.expand();
      final viewport = constraints.biggest;
      final (:photo, :pan) = PhotoWallpaper.crop(
        viewport,
        Size(image.width.toDouble(), image.height.toDouble()),
        widget.zoom,
      );
      return ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: (viewport.width - photo.width - pan.dx * widget.x) / 2,
              top: (viewport.height - photo.height - pan.dy * widget.y) / 2,
              width: photo.width,
              height: photo.height,
              child: RawImage(
                image: image,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                opacity: AlwaysStoppedAnimation(widget.opacity),
              ),
            ),
          ],
        ),
      );
    },
  );
}
