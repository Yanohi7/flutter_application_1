import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

Future<Uint8List?> showProfilePhotoCrop(
  BuildContext context,
  ui.Image image,
) async {
  final route = DialogRoute<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProfilePhotoCrop(image: image),
  );
  final result = await Navigator.of(context, rootNavigator: true).push(route);
  // The preview still paints during the closing transition.
  await route.completed;
  return result;
}

class _ProfilePhotoCrop extends StatefulWidget {
  const _ProfilePhotoCrop({required this.image});

  final ui.Image image;

  @override
  State<_ProfilePhotoCrop> createState() => _ProfilePhotoCropState();
}

class _ProfilePhotoCropState extends State<_ProfilePhotoCrop> {
  double _zoom = 1;
  double _gestureZoom = 1;
  Offset _pan = Offset.zero;
  bool _saving = false;
  bool _failed = false;

  Size get _cover {
    final ratio = widget.image.width / widget.image.height;
    return Size(math.max(1, ratio), math.max(1, 1 / ratio));
  }

  void _move(double zoom, Offset pan) {
    final cover = _cover;
    final x = (cover.width * zoom - 1) / 2;
    final y = (cover.height * zoom - 1) / 2;
    setState(() {
      _zoom = zoom;
      _pan = Offset(pan.dx.clamp(-x, x), pan.dy.clamp(-y, y));
    });
  }

  Rect _destination(double diameter) => Rect.fromCenter(
    center: Offset(diameter / 2, diameter / 2) + _pan * diameter,
    width: _cover.width * _zoom * diameter,
    height: _cover.height * _zoom * diameter,
  );

  Future<void> _apply() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      const side = 512;
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        widget.image,
        Rect.fromLTWH(
          0,
          0,
          widget.image.width.toDouble(),
          widget.image.height.toDouble(),
        ),
        _destination(side.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      try {
        final cropped = await picture.toImage(side, side);
        try {
          final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
          if (png == null) throw StateError('Could not render the photo.');
          if (mounted) {
            Navigator.pop(
              context,
              png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
            );
          }
        } finally {
          cropped.dispose();
        }
      } finally {
        picture.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Adjust profile photo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final diameter = math.min(280.0, constraints.maxWidth);
                        final image = _destination(diameter);
                        return GestureDetector(
                          onScaleStart: _saving
                              ? null
                              : (_) => _gestureZoom = _zoom,
                          onScaleUpdate: _saving
                              ? null
                              : (details) => _move(
                                  (_gestureZoom * details.scale).clamp(1, 4),
                                  _pan + details.focalPointDelta / diameter,
                                ),
                          child: SizedBox.square(
                            dimension: diameter,
                            child: ClipOval(
                              child: Stack(
                                children: [
                                  Positioned.fromRect(
                                    rect: image,
                                    child: RawImage(
                                      image: widget.image,
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Drag to reposition. Pinch or use the zoom slider.',
                    ),
                    Row(
                      children: [
                        const Icon(Icons.zoom_out),
                        Expanded(
                          child: Slider(
                            value: _zoom,
                            min: 1,
                            max: 4,
                            semanticFormatterCallback: (value) =>
                                '${(value * 100).round()}% zoom',
                            onChanged: _saving
                                ? null
                                : (zoom) => _move(zoom, _pan),
                          ),
                        ),
                        const Icon(Icons.zoom_in),
                      ],
                    ),
                    if (_failed)
                      const Text('Could not crop this photo. Try again.'),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: _saving ? null : _apply,
                    child: const Text('Use photo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
