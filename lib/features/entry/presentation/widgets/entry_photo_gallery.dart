// Display consistent thumbnails and open photos over a dimmed background

import 'dart:io';

import 'package:flutter/material.dart';

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
    // Keep the open viewer independent from edits to the underlying draft
    final images = List<MediaAttachment>.of(photos);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => StatefulBuilder(
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
                        tooltip: 'Close image',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      key: ValueKey(index),
                      minScale: 1,
                      maxScale: 5,
                      child: Center(
                        child: Image.file(
                          File(images[index].localPath),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Text(
                            'Could not open this image.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
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
                          tooltip: 'Previous image',
                          onPressed: index > 0
                              ? () => setState(() => index--)
                              : null,
                          icon: Icon(
                            Icons.chevron_left,
                            color: index > 0 ? Colors.white : Colors.white30,
                          ),
                        ),
                        const SizedBox(width: 24),
                        IconButton(
                          tooltip: 'Next image',
                          onPressed: index < images.length - 1
                              ? () => setState(() => index++)
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
    );
  }

  Future<void> _layout(BuildContext context, bool isExpanded) async {
    try {
      await appPreferences.setExpandedPhotos(isExpanded);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the image layout. Please try again.'),
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
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.grid_view_outlined, size: 16),
                    label: Text('Grid'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.view_agenda_outlined, size: 16),
                    label: Text('Full'),
                  ),
                ],
                selected: {isExpanded},
                onSelectionChanged: !isEnabled || appPreferences.isSaving
                    ? null
                    : (value) => _layout(context, value.single),
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
                alignment: WrapAlignment.center,
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
                    tooltip: 'Image actions',
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
                            caption.isEmpty ? 'Add caption' : 'Edit caption',
                          ),
                        ),
                      if (onRemove != null)
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove image'),
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
