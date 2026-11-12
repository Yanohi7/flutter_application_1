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
  if (background) {
    for (final pixel in canvas) {
      final blend = (pixel.x + pixel.y) / (2 * (size - 1));
      final alpha = rounded
          ? _coverage(pixel.x, pixel.y, 48, 48, 928, 928, 204)
          : 1.0;
      pixel.setRgba(
        38 - 17 * blend,
        62 - 31 * blend,
        83 - 31 * blend,
        255 * alpha,
      );
    }
  }
  if (!monochrome) {
    img.fillRect(
      canvas,
      x1: 313,
      y1: 277,
      x2: 744,
      y2: 776,
      radius: 67,
      color: img.ColorRgb8(114, 196, 169),
    );
  }
  img.fillRect(
    canvas,
    x1: 270,
    y1: 224,
    x2: 701,
    y2: 723,
    radius: 65,
    color: monochrome
        ? img.ColorRgb8(255, 255, 255)
        : img.ColorRgb8(214, 245, 232),
  );
  for (final (y, right) in [(347, 618), (450, 618), (553, 530)]) {
    if (monochrome) {
      for (var py = y; py < y + 32; py++) {
        for (var px = 350; px < right; px++) {
          final cut = _coverage(px, py, 350, y, right - 350, 32, 16);
          canvas.setPixelRgba(px, py, 255, 255, 255, 255 * (1 - cut));
        }
      }
    } else {
      img.fillRect(
        canvas,
        x1: 350,
        y1: y,
        x2: right - 1,
        y2: y + 31,
        radius: 16,
        color: img.ColorRgb8(25, 56, 70),
      );
    }
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
