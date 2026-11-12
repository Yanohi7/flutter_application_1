import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_video_thumbnail_plus/flutter_video_thumbnail_plus.dart';

import '../../data/datasources/entry_file_input.dart';
import '../../domain/entities/media_attachment.dart';

class EntryFileList extends StatefulWidget {
  const EntryFileList({
    super.key,
    required this.files,
    this.onRemove,
    this.isEnabled = true,
  });
  final List<MediaAttachment> files;
  final ValueChanged<MediaAttachment>? onRemove;
  final bool isEnabled;
  @override
  State<EntryFileList> createState() => _EntryFileListState();
}

class _EntryFileListState extends State<EntryFileList> {
  bool _isOpening = false;
  Future<void> _open(MediaAttachment file) async {
    if (_isOpening || !widget.isEnabled) return;
    setState(() => _isOpening = true);
    try {
      await EntryFileInput.open(file.localPath);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Could not open this file. It may no longer be available.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final file in widget.files)
        Padding(
          key: ValueKey(file.localPath),
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: file.fileType == 'video'
                  ? _VideoPreview(path: file.localPath)
                  : Icon(
                      file.fileName.toLowerCase().endsWith('.pdf')
                          ? Icons.picture_as_pdf_outlined
                          : Icons.insert_drive_file_outlined,
                    ),
              title: Text(
                file.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                file.fileSize == null
                    ? 'Open with another app'
                    : '${(file.fileSize! / 1024 / 1024).toStringAsFixed(2)} MB · Open with another app',
              ),
              onTap: widget.isEnabled && !_isOpening ? () => _open(file) : null,
              trailing: widget.onRemove == null
                  ? const Icon(Icons.open_in_new, size: 18)
                  : IconButton(
                      tooltip: 'Remove file',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: widget.isEnabled && !_isOpening
                          ? () => widget.onRemove!(file)
                          : null,
                    ),
            ),
          ),
        ),
    ],
  );
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.path});

  final String path;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final Future<Uint8List?> _thumbnail = _loadThumbnail(widget.path);

  Future<Uint8List?> _loadThumbnail(String path) async {
    try {
      return await FlutterVideoThumbnailPlus.thumbnailData(
        video: path,
        imageFormat: ImageFormat.jpeg,
        maxWidth: 240,
        quality: 80,
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.movie_outlined, color: colors.onSurfaceVariant),
      ),
    );

    return SizedBox(
      width: 72,
      height: 42,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Uint8List?>(
          future: _thumbnail,
          builder: (context, snapshot) {
            final thumbnail = snapshot.data;
            if (thumbnail == null || thumbnail.isEmpty) return placeholder;

            return Image.memory(
              thumbnail,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => placeholder,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame == null && !wasSynchronouslyLoaded) {
                  return placeholder;
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    child,
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
