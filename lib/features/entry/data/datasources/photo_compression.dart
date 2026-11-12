// Resize photos away from the UI isolate and retain the smaller encoded file

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

Future<String> compressEntryPhoto(
  (String source, String destination) input,
) async {
  final bytes = await File(input.$1).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.numFrames > 1) {
    return (await File(input.$1).copy(input.$2)).path;
  }
  var picture = img.bakeOrientation(decoded);
  if (picture.width > 2048 || picture.height > 2048) {
    picture = img.copyResize(
      picture,
      width: picture.width >= picture.height ? 2048 : null,
      height: picture.height > picture.width ? 2048 : null,
    );
  }
  final isTransparent = picture.hasAlpha;
  final encoded = isTransparent
      ? img.encodePng(picture)
      : img.encodeJpg(picture, quality: 85);
  if (encoded.length >= bytes.length) {
    return (await File(input.$1).copy(input.$2)).path;
  }
  final target = path.setExtension(input.$2, isTransparent ? '.png' : '.jpg');
  try {
    await File(target).writeAsBytes(encoded, flush: true);
  } catch (_) {
    final partial = File(target);
    if (await partial.exists()) await partial.delete();
    rethrow;
  }
  return target;
}
