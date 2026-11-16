import 'package:flutter_application_1/l10n/app_localizations.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../../../core/presentation/app_preferences.dart';
import '../../../../core/presentation/widgets/app_ui.dart';
import '../../../../core/presentation/widgets/wallpaper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../entry/presentation/pages/home_page.dart';

class PhotoComposition {
  const PhotoComposition(this.x, this.y, this.zoom, this.fade, this.opacity);
  final double x, y, zoom, fade, opacity;
}

class BackgroundPreviewPage extends StatefulWidget {
  const BackgroundPreviewPage({
    super.key,
    required this.path,
    required this.preferences,
    this.isExisting = false,
    this.onApply,
  }) : opacityOnly = false;

  const BackgroundPreviewPage.opacity({
    super.key,
    required this.preferences,
    this.onApply,
  }) : path = null,
       isExisting = true,
       opacityOnly = true;

  final String? path;
  final bool opacityOnly;
  final AppPreferences preferences;
  final bool isExisting;
  final Future<void> Function(PhotoComposition composition)? onApply;

  @override
  State<BackgroundPreviewPage> createState() => _BackgroundPreviewPageState();
}

class _BackgroundPreviewPageState extends State<BackgroundPreviewPage> {
  String? get _photoPath =>
      widget.opacityOnly ? widget.preferences.backgroundPath : widget.path;

  late double _x = widget.isExisting ? widget.preferences.photoX : 0;
  late double _y = widget.isExisting ? widget.preferences.photoY : 0;
  late double _zoom = widget.isExisting ? widget.preferences.photoZoom : 1;
  late double _fade = widget.isExisting ? widget.preferences.backgroundFade : 0;
  late double _opacity = widget.preferences.surfaceOpacity;
  double _gestureZoom = 1, _gestureX = 0, _gestureY = 0;
  Offset _gestureOrigin = Offset.zero;
  Offset? _pointerOrigin;
  int _pointerCount = 0;
  int _gesturePointerCount = 0;
  Size? _imageSize;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool _applying = false;
  bool _imageFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = _photoPath;
    if (_stream != null || path == null || widget.opacityOnly) return;
    _stream = PhotoWallpaper.imageProvider(
      path,
      context,
    ).resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener(
      (info, _) {
        if (mounted) {
          setState(
            () => _imageSize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            ),
          );
        }
        info.dispose();
      },
      onError: (Object _, StackTrace? _) {
        if (mounted) setState(() => _imageFailed = true);
      },
    );
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    super.dispose();
  }

  Future<void> _apply() async {
    if (_applying) return;
    final composition = PhotoComposition(_x, _y, _zoom, _fade, _opacity);
    final save = widget.onApply;
    if (save != null) {
      setState(() => _applying = true);
      try {
        await save(composition);
      } catch (_) {
        if (!mounted) return;
        setState(() => _applying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .couldNotSaveYourBackgroundPleaseTryAgain,
            ),
          ),
        );
        return;
      }
    }
    if (mounted) Navigator.pop(context, composition);
  }

  void _releasePointer() {
    _pointerCount = math.max(0, _pointerCount - 1);
    if (_pointerCount == 0) _pointerOrigin = null;
  }

  void _pan(ScaleUpdateDetails details, Size viewport) {
    final image = _imageSize;
    if (image == null) return;
    if (_gesturePointerCount != details.pointerCount) {
      _gesturePointerCount = details.pointerCount;
      _gestureOrigin = details.localFocalPoint;
      _gestureZoom = _zoom / details.scale;
      _gestureX = _x;
      _gestureY = _y;
    }
    final zoom = (_gestureZoom * details.scale).clamp(1.0, 3.0);
    final pan = PhotoWallpaper.crop(viewport, image, zoom).pan;
    final delta = details.localFocalPoint - _gestureOrigin;
    final x = pan.dx > 1
        ? (_gestureX - 2 * delta.dx / pan.dx).clamp(-1.0, 1.0)
        : 0.0;
    final y = pan.dy > 1
        ? (_gestureY - 2 * delta.dy / pan.dy).clamp(-1.0, 1.0)
        : 0.0;
    if (_zoom == zoom && _x == x && _y == y) return;
    setState(() {
      _zoom = zoom;
      _x = x;
      _y = y;
    });
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> update,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Slider(
        key: ValueKey(label.split(' · ').first),
        value: value,
        min: min,
        max: max,
        onChanged: (value) => setState(() => update(value)),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final photo = _photoPath;
    final theme = AppTheme.build(
      Theme.of(context).brightness,
      palette: widget.preferences.palette,
      surfaceOpacity: _opacity,
    ).copyWith(scaffoldBackgroundColor: Colors.transparent);
    return PopScope(
      canPop: !_applying,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.opacityOnly
                ? AppLocalizations.of(context)!.interfaceOpacity
                : AppLocalizations.of(context)!.previewBackground,
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  ReadablePanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      widget.opacityOnly
                          ? AppLocalizations.of(context)!
                                .previewTheChangeOnYourNotesBeforeApplyingIt
                          : AppLocalizations.of(context)!
                                .dragThePhotoToRepositionItOrPinchToZoom,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final maxHeight = (screen.height * 0.48).clamp(
                        180.0,
                        480.0,
                      );
                      final width = math.min(
                        constraints.maxWidth,
                        maxHeight * screen.width / screen.height,
                      );
                      final viewport = Size(
                        width,
                        width * screen.height / screen.width,
                      );
                      // Use the whole row for gestures while keeping the crop
                      // viewport at the device's aspect ratio.
                      return Listener(
                        onPointerDown: widget.opacityOnly
                            ? null
                            : (event) {
                                if (_pointerCount == 0) {
                                  _pointerOrigin = event.localPosition;
                                }
                                _pointerCount++;
                              },
                        onPointerUp: (_) => _releasePointer(),
                        onPointerCancel: (_) => _releasePointer(),
                        child: GestureDetector(
                          key: const Key('background-preview-stage'),
                          behavior: HitTestBehavior.opaque,
                          dragStartBehavior: DragStartBehavior.down,
                          onScaleStart: widget.opacityOnly
                              ? null
                              : (details) {
                                  _gesturePointerCount = details.pointerCount;
                                  _gestureOrigin = details.pointerCount <= 1
                                      ? (_pointerOrigin ??
                                            details.localFocalPoint)
                                      : details.localFocalPoint;
                                  _gestureZoom = _zoom;
                                  _gestureX = _x;
                                  _gestureY = _y;
                                },
                          onScaleUpdate: widget.opacityOnly
                              ? null
                              : (details) => _pan(details, viewport),
                          child: Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: viewport.width,
                              height: viewport.height,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: screen.width,
                                  height: screen.height,
                                  child: MediaQuery(
                                    data: media.copyWith(
                                      size: screen,
                                      padding: EdgeInsets.zero,
                                      viewPadding: EdgeInsets.zero,
                                      viewInsets: EdgeInsets.zero,
                                    ),
                                    child: Theme(
                                      data: theme,
                                      child: IgnorePointer(
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ThemeWallpaper(
                                              style: widget
                                                  .preferences
                                                  .backgroundStyle,
                                            ),
                                            if (photo != null)
                                              Opacity(
                                                opacity: 1 - _fade,
                                                child: PhotoWallpaper(
                                                  path: photo,
                                                  x: _x,
                                                  y: _y,
                                                  zoom: _zoom,
                                                ),
                                              ),
                                            const HomePage(isPreview: true),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  ReadablePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!widget.opacityOnly) ...[
                          _slider(
                            'Zoom · ${(_zoom * 100).round()}%',
                            _zoom,
                            1,
                            3,
                            (value) => _zoom = value,
                          ),
                          _slider(
                            'Photo opacity · ${((1 - _fade) * 100).round()}%',
                            1 - _fade,
                            0.04,
                            1,
                            (value) => _fade = 1 - value,
                          ),
                        ],
                        _slider(
                          'Interface opacity · ${(_opacity * 100).round()}%',
                          _opacity,
                          0.25,
                          1,
                          (value) => _opacity = value,
                        ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (!widget.opacityOnly)
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _x = 0;
                                  _y = 0;
                                  _zoom = 1;
                                }),
                                icon: const Icon(Icons.center_focus_strong),
                                label: Text(
                                  AppLocalizations.of(context)!.resetFraming,
                                ),
                              ),
                            FilledButton(
                              onPressed:
                                  _applying ||
                                      (!widget.opacityOnly &&
                                          _imageSize == null)
                                  ? null
                                  : _apply,
                              child: Text(
                                _applying
                                    ? AppLocalizations.of(context)!.saving
                                    : widget.opacityOnly
                                    ? AppLocalizations.of(context)!.applyOpacity
                                    : AppLocalizations.of(context)!
                                          .applyBackground,
                              ),
                            ),
                          ],
                        ),
                        if (_imageFailed)
                          Text(
                            AppLocalizations.of(context)!.couldNotOpenThisImage,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
