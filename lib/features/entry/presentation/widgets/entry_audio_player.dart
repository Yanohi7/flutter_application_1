import 'package:flutter_application_1/l10n/app_localizations.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/media_attachment.dart';
import '../cubit/entry_cubit.dart';
import '../cubit/entry_state.dart';
import '../entry_playback.dart';

class EntryPlaybackObserver extends StatelessWidget {
  const EntryPlaybackObserver({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => BlocListener<EntryCubit, EntryState>(
    listenWhen: (before, after) {
      if (identical(before.entries, after.entries)) return false;
      final path = context.read<EntryPlayback>().track?.localPath;
      if (path == null) return false;
      bool hasTrack(EntryState state) => state.entries.any(
        (entry) => entry.attachments.any((file) => file.localPath == path),
      );
      return hasTrack(before) && !hasTrack(after);
    },
    listener: (context, _) {
      final playback = context.read<EntryPlayback>();
      final path = playback.track?.localPath;
      if (path != null) unawaited(playback.stopIfPath(path));
    },
    child: child,
  );
}

class EntryAudioPlayer extends StatelessWidget {
  const EntryAudioPlayer({
    super.key,
    required this.attachments,
    this.onRename,
    this.onRemove,
    this.isEnabled = true,
  });

  final Iterable<MediaAttachment> attachments;
  final ValueChanged<MediaAttachment>? onRename;
  final ValueChanged<MediaAttachment>? onRemove;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final playback = context.read<EntryPlayback>();
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final enabled = isEnabled && !playback.isBusy;
        return Column(
          children: [
            for (final attachment in attachments)
              Container(
                key: ValueKey(attachment.localPath),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: _attachmentControls(
                  context,
                  playback,
                  attachment,
                  enabled,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _attachmentControls(
    BuildContext context,
    EntryPlayback playback,
    MediaAttachment attachment,
    bool enabled,
  ) {
    final active = playback.track?.localPath == attachment.localPath;
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: active && playback.isPlaying
                  ? AppLocalizations.of(context)!.pauseAudio
                  : AppLocalizations.of(context)!.playAudio,
              onPressed: enabled
                  ? () => _run(
                      context,
                      playback.toggle(attachment),
                      AppLocalizations.of(context)!.couldNotPlayThisAudioFile,
                    )
                  : null,
              icon: Icon(
                active && playback.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.audioTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  if (active)
                    _PlaybackTime(playback)
                  else
                    Text(
                      AppLocalizations.of(context)!.tapToListen,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (onRename != null)
              IconButton(
                tooltip: AppLocalizations.of(context)!.renameAudio,
                onPressed: enabled ? () => onRename!(attachment) : null,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
            if (onRemove != null)
              IconButton(
                tooltip: AppLocalizations.of(context)!.removeAudio,
                onPressed: enabled ? () => onRemove!(attachment) : null,
                icon: const Icon(Icons.close, size: 20),
              ),
          ],
        ),
        if (active)
          Row(
            children: [
              Expanded(child: _PlaybackSlider(playback, enabled: enabled)),
              _PlaybackSpeed(playback, enabled: enabled),
            ],
          ),
      ],
    );
  }
}

class EntryMiniPlayer extends StatelessWidget {
  const EntryMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final playback = context.read<EntryPlayback>();
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final track = playback.track;
        if (track == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final enabled = !playback.isBusy;
        return Material(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: playback.isPlaying
                          ? AppLocalizations.of(context)!.pauseAudio
                          : AppLocalizations.of(context)!.playAudio,
                      onPressed: enabled
                          ? () => _run(
                              context,
                              playback.toggle(track),
                              AppLocalizations.of(context)!
                                  .couldNotPlayThisAudioFile,
                            )
                          : null,
                      icon: Icon(
                        playback.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.audioTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          _PlaybackTime(playback),
                        ],
                      ),
                    ),
                    _PlaybackSpeed(playback, enabled: enabled),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.closePlayer,
                      onPressed: enabled
                          ? () => _run(
                              context,
                              playback.stop(),
                              AppLocalizations.of(context)!
                                  .couldNotStopPlayback,
                            )
                          : null,
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
              _PlaybackSlider(
                playback,
                key: ValueKey(track.localPath),
                enabled: enabled,
              ),
              const Divider(),
            ],
          ),
        );
      },
    );
  }
}

class _PlaybackTime extends StatelessWidget {
  const _PlaybackTime(this.playback);

  final EntryPlayback playback;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: playback.position,
    builder: (context, position, _) => Text(
      '${_time(position)} / ${_time(playback.duration)}',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );

  static String _time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _PlaybackSpeed extends StatelessWidget {
  const _PlaybackSpeed(this.playback, {required this.enabled});

  final EntryPlayback playback;
  final bool enabled;

  @override
  Widget build(BuildContext context) => PopupMenuButton<double>(
    tooltip: AppLocalizations.of(context)!.playbackSpeed,
    enabled: enabled,
    initialValue: playback.speed,
    onSelected: (speed) => _run(
      context,
      playback.setSpeed(speed),
      AppLocalizations.of(context)!.couldNotChangePlaybackSpeedForThisAudioFile,
    ),
    itemBuilder: (_) => [
      for (final speed in EntryPlayback.speeds)
        PopupMenuItem(value: speed, child: Text(_label(speed))),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(_label(playback.speed)),
    ),
  );

  static String _label(double rate) =>
      '${rate == rate.truncateToDouble() ? rate.toInt() : rate}×';
}

class _PlaybackSlider extends StatefulWidget {
  const _PlaybackSlider(this.playback, {super.key, required this.enabled});

  final EntryPlayback playback;
  final bool enabled;

  @override
  State<_PlaybackSlider> createState() => _PlaybackSliderState();
}

class _PlaybackSliderState extends State<_PlaybackSlider> {
  double? _dragPosition;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: widget.playback.position,
    builder: (context, position, _) {
      final length = widget.playback.duration.inMilliseconds.toDouble();
      return SliderTheme(
        data: SliderTheme.of(context).copyWith(trackHeight: 3),
        child: Slider(
          value: (_dragPosition ?? position.inMilliseconds.toDouble()).clamp(
            0,
            length,
          ),
          max: length == 0 ? 1 : length,
          onChanged: widget.enabled && length > 0
              ? (value) => setState(() => _dragPosition = value)
              : null,
          onChangeEnd: (value) async {
            await _run(
              context,
              widget.playback.seek(Duration(milliseconds: value.round())),
              AppLocalizations.of(context)!.couldNotSeekThisAudioFile,
            );
            if (mounted) setState(() => _dragPosition = null);
          },
        ),
      );
    },
  );
}

Future<void> _run(
  BuildContext context,
  Future<bool> action,
  String error,
) async {
  if (await action || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
}
