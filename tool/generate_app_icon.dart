import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  Directory('assets/branding').createSync(recursive: true);
  final standard = _draw(background: true);
  final desktop = _draw(background: true, rounded: true);
  _write('assets/branding/entries-icon.png', standard);
  _write('assets/branding/entries-desktop.png', desktop);
  _write('assets/branding/entries-foreground.png', _draw());
  _write('assets/branding/entries-monochrome.png', _draw(monochrome: true));
  Directory('linux/runner/resources').createSync(recursive: true);
  _write('linux/runner/resources/entries.png', _resize(desktop, 256));
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(
    img.IcoEncoder().encodeImages([
      for (final size in [16, 20, 24, 32, 40, 48, 64, 128, 256])
        _resize(desktop, size),
    ]),
  );
}

img.Image _draw({
  bool background = false,
  bool rounded = false,
  bool monochrome = false,
}) {
  const size = 1024;
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  const navy = (19, 30, 46);
  const paper = (245, 248, 250);
  for (final pixel in canvas) {
    final x = pixel.x;
    final y = pixel.y;
    final outer = _coverage(x, y, 298, 246, 428, 532, 80);
    final inner = _coverage(x, y, 348, 296, 328, 432, 34);
    final ink = outer * (1 - inner);
    if (background) {
      final alpha = rounded ? _coverage(x, y, 48, 48, 928, 928, 204) : 1.0;
      pixel.setRgba(
        navy.$1 + (paper.$1 - navy.$1) * ink,
        navy.$2 + (paper.$2 - navy.$2) * ink,
        navy.$3 + (paper.$3 - navy.$3) * ink,
        255 * alpha,
      );
    } else if (ink > 0) {
      pixel.setRgba(
        monochrome ? 255 : paper.$1,
        monochrome ? 255 : paper.$2,
        monochrome ? 255 : paper.$3,
        255 * ink,
      );
    }
  }
  for (final (y, width) in [(400, 204), (492, 204), (584, 126)]) {
    img.fillRect(
      canvas,
      x1: 410,
      y1: y,
      x2: 409 + width,
      y2: y + 37,
      radius: 19,
      color: monochrome
          ? img.ColorRgb8(255, 255, 255)
          : y == 584
          ? img.ColorRgb8(114, 222, 192)
          : img.ColorRgb8(paper.$1, paper.$2, paper.$3),
    );
  }
  return canvas;
}

double _coverage(
  int x,
  int y,
  int left,
  int top,
  int width,
  int height,
  int radius,
) {
  final dx = (x + .5 - left - width / 2).abs() - (width / 2 - radius);
  final dy = (y + .5 - top - height / 2).abs() - (height / 2 - radius);
  final outsideX = math.max(dx, 0);
  final outsideY = math.max(dy, 0);
  final distance =
      math.sqrt(outsideX * outsideX + outsideY * outsideY) +
      math.min(math.max(dx, dy), 0) -
      radius;
  return (.5 - distance).clamp(0, 1);
}

img.Image _resize(img.Image source, int size) => img.copyResize(
  source,
  width: size,
  height: size,
  interpolation: img.Interpolation.average,
);

void _write(String path, img.Image image) =>
    File(path).writeAsBytesSync(img.encodePng(image));
