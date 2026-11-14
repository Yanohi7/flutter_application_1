// Display a compact entry preview, category path and quick actions without writing storage directly

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/app_preferences.dart';
import '../../../../core/utils/datetime_helpers.dart';
import '../../../category/presentation/cubit/category_cubit.dart';
import '../../domain/entities/entry.dart';
import 'entry_formatted_content.dart';

class EntryCard extends StatelessWidget {
  final Entry entry;
  final bool enabled;
  final bool showCategoryPath;
  final NoteCardSize cardSize;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onFavorite;
  final VoidCallback onActions;
  const EntryCard({
    super.key,
    required this.entry,
    required this.enabled,
    this.showCategoryPath = false,
    this.cardSize = NoteCardSize.standard,
    required this.onTap,
    required this.onPin,
    required this.onFavorite,
    required this.onActions,
  });

  @override
  Widget build(BuildContext context) {
    final content = entrySearchText(entry.content);
    var location = entry.categoryName;
    // Only resolve visible paths and listen to category data rather than every Cubit state
    if (showCategoryPath) {
      location =
          context.select(
            (CategoryCubit cubit) => cubit.state.pathLabel(entry.categoryId),
          ) ??
          location;
    }
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final compact = cardSize == NoteCardSize.compact;
    final large = cardSize == NoteCardSize.large;

    Widget action(
      String tooltip,
      IconData icon,
      Color color,
      VoidCallback callback, {
      double? width,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: enabled ? callback : null,
        icon: Icon(icon, size: 19, color: color),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
          width: width ?? (compact ? 30 : 38),
          height: 38,
        ),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        // Open the same action menu from a long press or the ellipsis button
        onLongPress: enabled ? onActions : null,
        child: Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(10, 6, 8, 6)
              : const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title?.isNotEmpty == true
                          ? entry.title!
                          : AppLocalizations.of(context)!.untitled,
                      maxLines: large ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  action(
                    AppLocalizations.of(context)!.entryActions,
                    Icons.more_horiz,
                    muted,
                    onActions,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  content.isEmpty
                      ? AppLocalizations.of(context)!.noTextYet
                      : content,
                  maxLines: compact
                      ? 1
                      : large
                      ? 5
                      : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, height: 1.4, color: muted),
                ),
              ),
              // Only the global list needs a path and tapping it reveals the full text
              if (showCategoryPath)
                InkWell(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(AppLocalizations.of(context)!.categoryPath),
                      content: SingleChildScrollView(
                        child: SelectableText(location),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(AppLocalizations.of(context)!.close),
                        ),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final actionWidth = width >= 176
                      ? 36.0
                      : width >= 145
                      ? 30.0
                      : 24.0;
                  final iconSize = width >= 176 ? 14.0 : 12.0;
                  final kinds = entry.attachments
                      .map((file) => file.fileType)
                      .toSet();
                  final indicators = [
                    if (kinds.contains('document') || kinds.contains('video'))
                      (Icons.attach_file, AppLocalizations.of(context)!.files),
                    if (kinds.contains('audio'))
                      (Icons.mic_none, AppLocalizations.of(context)!.audio),
                    if (kinds.contains('photo'))
                      (
                        Icons.image_outlined,
                        AppLocalizations.of(context)!.images,
                      ),
                  ];
                  final dateWidth =
                      width -
                      actionWidth * 2 -
                      indicators.length * (iconSize + 3);
                  final fontScale =
                      MediaQuery.textScalerOf(context).scale(10) / 10;
                  final fullDate = formatEntryDate(entry.createdAt);
                  final dateFormat = dateWidth >= 54 * fontScale
                      ? EntryDateFormat.full
                      : dateWidth >= 42 * fontScale
                      ? EntryDateFormat.shortYear
                      : EntryDateFormat.dayAndMonth;
                  return Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Tooltip(
                                message: fullDate,
                                child: Text(
                                  formatEntryDate(
                                    entry.createdAt,
                                    format: dateFormat,
                                  ),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10, color: muted),
                                ),
                              ),
                            ),
                            for (final (icon, label) in indicators)
                              Padding(
                                padding: const EdgeInsets.only(left: 3),
                                child: Tooltip(
                                  message: label,
                                  child: Icon(
                                    icon,
                                    size: iconSize,
                                    color: muted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      action(
                        entry.isFavorite
                            ? AppLocalizations.of(context)!.removeFromFavorites
                            : AppLocalizations.of(context)!.addToFavorites,
                        entry.isFavorite ? Icons.star : Icons.star_border,
                        entry.isFavorite ? AppColors.favorite : muted,
                        onFavorite,
                        width: actionWidth,
                      ),
                      action(
                        entry.isPinned
                            ? AppLocalizations.of(context)!.unpin
                            : AppLocalizations.of(context)!.pin,
                        entry.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        entry.isPinned ? AppColors.pin : muted,
                        onPin,
                        width: actionWidth,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
