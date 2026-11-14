// Lay out entry cards in a responsive sliver grid inside the main scroll view

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/presentation/app_preferences.dart';
import '../../../../core/presentation/widgets/app_ui.dart';
import '../../domain/entities/entry.dart';
import 'entry_card.dart';

/// A sliver within the shared CustomScrollView, with no nested scrolling
class EntriesGrid extends StatelessWidget {
  final List<Entry> entries;
  final bool enabled;
  final bool showCategoryPath;
  final NoteCardSize cardSize;
  final ValueChanged<Entry> onOpen;
  final ValueChanged<Entry> onPin;
  final ValueChanged<Entry> onFavorite;
  final ValueChanged<Entry> onActions;

  const EntriesGrid({
    super.key,
    required this.entries,
    required this.enabled,
    this.showCategoryPath = false,
    this.cardSize = NoteCardSize.standard,
    required this.onOpen,
    required this.onPin,
    required this.onFavorite,
    required this.onActions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final layout = _EntryGridLayout(cardSize, MediaQuery.textScalerOf(context));
    final pinned = entries.where((entry) => entry.isPinned).toList();
    final other = entries.where((entry) => !entry.isPinned).toList();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      sliver: SliverMainAxisGroup(
        slivers: [
          if (pinned.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 3, 4, 10),
                child: Semantics(
                  header: true,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: WallpaperTextSurface(
                      child: Text(
                        AppLocalizations.of(context)!.pinned,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _grid(pinned, layout),
            if (other.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Divider(height: 1, color: colors.outlineVariant),
                ),
              ),
          ],
          if (other.isNotEmpty) _grid(other, layout),
        ],
      ),
    );
  }

  Widget _grid(List<Entry> section, SliverGridDelegate layout) => SliverGrid(
    gridDelegate: layout,
    delegate: SliverChildBuilderDelegate((context, index) {
      final entry = section[index];
      return EntryCard(
        key: ValueKey(entry.id),
        entry: entry,
        enabled: enabled,
        showCategoryPath: showCategoryPath,
        cardSize: cardSize,
        onTap: () => onOpen(entry),
        onPin: () => onPin(entry),
        onFavorite: () => onFavorite(entry),
        onActions: () => onActions(entry),
      );
    }, childCount: section.length),
  );
}

class _EntryGridLayout extends SliverGridDelegate {
  const _EntryGridLayout(this.cardSize, this.textScaler);

  final NoteCardSize cardSize;
  final TextScaler textScaler;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final scale = textScaler.scale(14) / 14;
    final (
      cardWidth,
      maxColumns,
      fixedHeight,
      scalableHeight,
    ) = switch (cardSize) {
      NoteCardSize.compact => (136.0, 6, 92.0, 73.0),
      NoteCardSize.standard => (154.0, 4, 105.0, 105.0),
      NoteCardSize.large => (272.0, 3, 110.0, 150.0),
    };
    final minWidth = cardWidth * scale.clamp(1.0, 2.0);
    const gap = 12.0; // Use the same horizontal and vertical gap
    final columns = ((constraints.crossAxisExtent + gap) / (minWidth + gap))
        .floor()
        .clamp(
          1,
          maxColumns,
        ); // Use 1-2 columns on phones and up to 4 on wider screens
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      // The gap between adjacent columns
      crossAxisSpacing: gap,
      // The gap between grid rows
      mainAxisSpacing: gap,
      mainAxisExtent: fixedHeight + textScaler.scale(scalableHeight),
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(covariant _EntryGridLayout oldDelegate) =>
      cardSize != oldDelegate.cardSize || textScaler != oldDelegate.textScaler;
}
