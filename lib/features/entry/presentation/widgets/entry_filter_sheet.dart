// Collect temporary sort and filter choices and return them only when the user applies them

import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_ui.dart';

class EntryViewOptions {
  final String sort;
  final String time;
  final String content;
  const EntryViewOptions({
    this.sort = 'Newest',
    this.time = 'All time',
    this.content = 'All types',
  });
}

Future<EntryViewOptions?> showEntryFilters(
  BuildContext context,
  EntryViewOptions options,
) {
  return showModalBottomSheet<EntryViewOptions>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FilterSheet(initial: options),
  );
}

class _FilterSheet extends StatefulWidget {
  final EntryViewOptions initial;
  const _FilterSheet({required this.initial});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  // Keep draft choices in the sheet so dismissing it does not apply unfinished changes
  late String _sort = widget.initial.sort;
  late String _time = widget.initial.time;
  late String _content = widget.initial.content;

  Widget _choices(
    List<String> values,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(
              value,
              style: TextStyle(
                color: value == selected ? colors.onPrimary : colors.onSurface,
              ),
            ),
            selected: value == selected,
            onSelected: (_) => setState(() => onChanged(value)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filter & Sort',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _sort = 'Newest';
                  _time = 'All time';
                  _content = 'All types';
                }),
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FieldLabel('Sort by'),
          _choices(
            ['Newest', 'Oldest', 'A–Z', 'Z–A', 'Last edited'],
            _sort,
            (value) => _sort = value,
          ),
          const SizedBox(height: 20),
          const FieldLabel('Date created'),
          _choices(
            ['All time', 'Today', 'This week', 'This month'],
            _time,
            (value) => _time = value,
          ),
          const SizedBox(height: 20),
          const FieldLabel('Content'),
          _choices(
            ['All types', 'Checklist', 'Image', 'Audio', 'File'],
            _content,
            (value) => _content = value,
          ),
          const SizedBox(height: 24),
          // Return the complete selection to HomePage only when Apply is pressed
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              EntryViewOptions(sort: _sort, time: _time, content: _content),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}
