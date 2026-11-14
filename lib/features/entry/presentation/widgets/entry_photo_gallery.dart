import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

import '../../../../core/presentation/app_preferences.dart';
import '../../domain/entities/media_attachment.dart';

class EntryPhotoGallery extends StatelessWidget {
  const EntryPhotoGallery({
    super.key,
    required this.photos,
    this.onCaption,
    this.onRemove,
    this.isEnabled = true,
  });

  final List<MediaAttachment> photos;
  final ValueChanged<int>? onCaption;
  final ValueChanged<int>? onRemove;
  final bool isEnabled;

  Future<void> _open(BuildContext context, int initialIndex) async {
    var index = initialIndex;
    final pages = PageController(initialPage: initialIndex);
    var zoomed = false;
    // Keep the open viewer independent from edits to the underlying draft
    final images = List<MediaAttachment>.of(photos);
    void step(int direction) {
      final target = index + direction;
      if (!pages.hasClients || target < 0 || target >= images.length) return;
      pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }

    final route = DialogRoute<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => step(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => step(1),
        },
        child: Focus(
          autofocus: true,
          child: StatefulBuilder(
            builder: (context, setState) => Dialog(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.85,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '${index + 1} / ${images.length}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: AppLocalizations.of(context)!.closeImage,
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: pages,
                          scrollBehavior: ScrollConfiguration.of(context)
                              .copyWith(
                                dragDevices: {
                                  ...ScrollConfiguration.of(context)
                                      .dragDevices,
                                  PointerDeviceKind.mouse,
                                },
                              ),
                          physics: zoomed
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          itemCount: images.length,
                          onPageChanged: (value) => setState(() {
                            index = value;
                            zoomed = false;
                          }),
                          itemBuilder: (context, page) => _GalleryImage(
                            key: ValueKey(page),
                            image: images[page],
                            onZoomChanged: (value) {
                              if (page == index && zoomed != value) {
                                setState(() => zoomed = value);
                              }
                            },
                          ),
                        ),
                      ),
                      if (images[index].displayName?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            images[index].displayName!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      if (images.length > 1)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: AppLocalizations.of(context)!
                                  .previousImage,
                              onPressed: index > 0 ? () => step(-1) : null,
                              icon: Icon(
                                Icons.chevron_left,
                                color: index > 0
                                    ? Colors.white
                                    : Colors.white30,
                              ),
                            ),
                            const SizedBox(width: 24),
                            IconButton(
                              tooltip: AppLocalizations.of(context)!.nextImage,
                              onPressed: index < images.length - 1
                                  ? () => step(1)
                                  : null,
                              icon: Icon(
                                Icons.chevron_right,
                                color: index < images.length - 1
                                    ? Colors.white
                                    : Colors.white30,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    pages.dispose();
  }

  Future<void> _layout(BuildContext context, bool isExpanded) async {
    try {
      await appPreferences.setExpandedPhotos(isExpanded);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .couldNotSaveTheImageLayoutPleaseTryAgain,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: appPreferences,
      builder: (context, _) {
        final isExpanded = appPreferences.isExpandedPhotos;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: LayoutBuilder(
                builder: (context, constraints) => SegmentedButton<bool>(
                  direction:
                      constraints.maxWidth <
                          MediaQuery.textScalerOf(context).scale(190)
                      ? Axis.vertical
                      : Axis.horizontal,
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.grid_view_outlined, size: 16),
                      label: Text(AppLocalizations.of(context)!.grid),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.view_agenda_outlined, size: 16),
                      label: Text(AppLocalizations.of(context)!.full),
                    ),
                  ],
                  selected: {isExpanded},
                  onSelectionChanged: !isEnabled || appPreferences.isSaving
                      ? null
                      : (value) => _layout(context, value.single),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (isExpanded)
              Column(
                children: [
                  for (var index = 0; index < photos.length; index++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: index == photos.length - 1 ? 0 : 16,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: _photo(context, index, isExpanded: true),
                        ),
                      ),
                    ),
                ],
              )
            else
              Wrap(
                alignment: WrapAlignment.start,
                spacing: 10,
                runSpacing: 12,
                children: [
                  for (var index = 0; index < photos.length; index++)
                    SizedBox(
                      width: 104,
                      child: _photo(context, index, isExpanded: false),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _photo(BuildContext context, int index, {required bool isExpanded}) {
    final photo = photos[index];
    final caption = photo.displayName?.trim() ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isEnabled ? () => _open(context, index) : null,
                child: ConstrainedBox(
                  constraints: isExpanded
                      ? const BoxConstraints(maxHeight: 480)
                      : const BoxConstraints.tightFor(width: 104, height: 104),
                  child: Image.file(
                    File(photo.localPath),
                    fit: isExpanded ? BoxFit.contain : BoxFit.cover,
                    cacheWidth: isExpanded ? 1400 : 320,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 104,
                      height: 104,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
            if (onRemove != null || onCaption != null)
              Positioned(
                top: 2,
                right: 2,
                child: Material(
                  type: MaterialType.transparency,
                  child: PopupMenuButton<String>(
                    tooltip: AppLocalizations.of(context)!.imageActions,
                    enabled: isEnabled,
                    icon: const Icon(
                      Icons.more_horiz,
                      size: 20,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
                    ),
                    onSelected: (action) {
                      if (action == 'caption') onCaption?.call(index);
                      if (action == 'remove') onRemove?.call(index);
                    },
                    itemBuilder: (_) => [
                      if (onCaption != null)
                        PopupMenuItem(
                          value: 'caption',
                          child: Text(
                            caption.isEmpty
                                ? AppLocalizations.of(context)!.addCaption
                                : AppLocalizations.of(context)!.editCaption,
                          ),
                        ),
                      if (onRemove != null)
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(
                            AppLocalizations.of(context)!.removeImage,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Tooltip(
              message: caption,
              child: Text(
                caption,
                textAlign: TextAlign.center,
                maxLines: isExpanded ? null : 2,
                overflow: isExpanded ? null : TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }
}

class _GalleryImage extends StatefulWidget {
  const _GalleryImage({
    super.key,
    required this.image,
    required this.onZoomChanged,
  });
  final MediaAttachment image;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_GalleryImage> createState() => _GalleryImageState();
}

class _GalleryImageState extends State<_GalleryImage> {
  final _transform = TransformationController();
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_updateZoom);
  }

  void _updateZoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (_zoomed == zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged(zoomed);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    transformationController: _transform,
    panEnabled: _zoomed,
    maxScale: 5,
    child: Center(
      child: Image.file(
        File(widget.image.localPath),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Text(
          AppLocalizations.of(context)!.couldNotOpenThisImage,
          style: TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
}
