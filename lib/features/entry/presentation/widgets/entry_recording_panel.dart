// Group live recording levels, duration and pause or stop controls in one surface

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class EntryRecordingPanel extends StatelessWidget {
  const EntryRecordingPanel({
    super.key,
    required this.elapsed,
    required this.levels,
    required this.isPaused,
    required this.isBusy,
    required this.onPause,
    required this.onStop,
  });
  final Duration elapsed;
  final List<double> levels;
  final bool isPaused;
  final bool isBusy;
  final VoidCallback onPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isPaused ? Icons.pause_circle_outline : Icons.mic,
                size: 20,
                color: isPaused
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPaused
                      ? AppLocalizations.of(context)!.paused
                      : AppLocalizations.of(context)!.recording,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                '${elapsed.inMinutes}:$seconds',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: Row(
              children: [
                // Keep a fixed number of bars so the waveform never stretches or jumps in width
                for (var index = 0; index < 40; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          height:
                              3 +
                              (index < 40 - levels.length
                                      ? 0
                                      : levels[index - (40 - levels.length)]) *
                                  30,
                          decoration: BoxDecoration(
                            color: isPaused
                                ? theme.colorScheme.outline
                                : theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: isBusy ? null : onPause,
                icon: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 20,
                ),
                label: Text(
                  isPaused
                      ? AppLocalizations.of(context)!.resume
                      : AppLocalizations.of(context)!.pause,
                ),
              ),
              FilledButton.icon(
                onPressed: isBusy ? null : onStop,
                icon: const Icon(Icons.stop_rounded, size: 20),
                label: Text(AppLocalizations.of(context)!.finish),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
