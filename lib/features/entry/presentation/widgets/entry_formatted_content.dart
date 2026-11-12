// Encode structured blocks compatibly and render them inside the note document.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'entry_table_viewport.dart';

const _checklistPrefix = '::entry-checklist ';
const _listPrefix = '::entry-list ';
const _tablePrefix = '::entry-table ';

bool _mayHaveStructure(String content) =>
    content.contains('::entry-') ||
    content.contains('|') ||
    content.contains('- [');

bool _hasEncodedBlock(String line) =>
    line.startsWith(_checklistPrefix) ||
    line.startsWith(_listPrefix) ||
    line.startsWith(_tablePrefix);

typedef _Item = ({String text, bool checked});
typedef _Checklist = ({String title, List<_Item> items});
typedef _Table = ({String title, List<List<String>> rows});

typedef _PlainList = ({String title, String marker, List<String> items});

class _Extras {
  final lists = <_PlainList>[];
  final alignments = <Object, int>{};
  final checklists = <_Checklist>[];
  final tables = <_Table>[];

  String encode() => [
    for (final checklist in checklists)
      '$_checklistPrefix${jsonEncode({
        'title': checklist.title,
        'alignment': alignments[checklist.items] ?? 0,
        'items': [
          for (final item in checklist.items) {'text': item.text, 'checked': item.checked},
        ],
      })}',
    for (final table in tables)
      '$_tablePrefix${jsonEncode({'title': table.title, 'rows': table.rows, 'alignment': alignments[table.rows] ?? 0})}',
    for (final list in lists)
      '$_listPrefix${jsonEncode({'title': list.title, 'marker': list.marker, 'items': list.items, 'alignment': alignments[list.items] ?? 0})}',
  ].join('\n');
}

// Keep older saved entries left aligned and ignore invalid alignment values
int _alignment(Map<String, dynamic>? data) =>
    data?['alignment'] is int ? (data!['alignment'] as int).clamp(0, 2) : 0;

Map<String, dynamic>? _decode(String line, String prefix) {
  if (!line.startsWith(prefix)) return null;
  try {
    final value = jsonDecode(line.substring(prefix.length));
    return value is Map<String, dynamic> ? value : null;
  } on FormatException {
    return null;
  }
}

List<String>? _legacyCells(String line) {
  final value = line.trim();
  if (value.length < 2 || !value.startsWith('|') || !value.endsWith('|')) {
    return null;
  }
  final cells = value.split('|');
  return [
    for (final cell in cells.sublist(1, cells.length - 1))
      cell.trim().replaceAll('&#124;', '|').replaceAll('&amp;', '&'),
  ];
}

({String text, _Extras extras}) _readContent(String content) {
  final text = <String>[];
  final extras = _Extras();
  final lines = content.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final checklistData = _decode(line, _checklistPrefix);
    if (checklistData case {
      'title': final String title,
      'items': final List<dynamic> items,
    }) {
      extras.checklists.add((
        title: title,
        items: [
          for (final item in items)
            if (item case {
              'text': final String text,
              'checked': final bool checked,
            })
              (text: text, checked: checked),
        ],
      ));
      extras.alignments[extras.checklists.last.items] = _alignment(
        checklistData,
      );
      continue;
    }
    final listData = _decode(line, _listPrefix);
    if (listData case {
      'title': final String title,
      'items': final List<dynamic> items,
    }) {
      final list = (
        title: title,
        marker: listData['marker'] is String
            ? listData['marker'] as String
            : 'bullet',
        items: items.whereType<String>().toList(),
      );
      extras.lists.add(list);
      extras.alignments[list.items] = _alignment(listData);
      continue;
    }
    final tableData = _decode(line, _tablePrefix);
    if (tableData case {
      'title': final String title,
      'rows': final List<dynamic> storedRows,
    }) {
      final rows = [
        for (final row in storedRows)
          if (row is List &&
              row.isNotEmpty &&
              row.every((cell) => cell is String))
            List<String>.of(row.cast<String>()),
      ];
      if (rows.isNotEmpty &&
          rows.every((row) => row.length == rows.first.length)) {
        extras.tables.add((title: title, rows: rows));
        extras.alignments[rows] = _alignment(tableData);
        continue;
      }
    }

    // Read tables and checkboxes saved by the previous editor
    final header = _legacyCells(line);
    final separator =
        header != null && header.isNotEmpty && index + 1 < lines.length
        ? _legacyCells(lines[index + 1])
        : null;
    if (header != null &&
        header.isNotEmpty &&
        separator != null &&
        separator.length == header.length &&
        separator.every((cell) => cell == '---')) {
      final rows = [header];
      index++;
      while (index + 1 < lines.length) {
        final row = _legacyCells(lines[index + 1]);
        if (row == null || row.length != header.length) break;
        rows.add(row);
        index++;
      }
      extras.tables.add((title: '', rows: rows));
    } else if (line.startsWith('- [ ] ') || line.startsWith('- [x] ')) {
      extras.checklists.add((
        title: '',
        items: [(text: line.substring(6), checked: line[3] == 'x')],
      ));
    } else {
      text.add(line);
    }
  }
  return (text: text.join('\n'), extras: extras);
}

({String text, String extras}) splitEntryContent(String content) {
  if (!_mayHaveStructure(content)) return (text: content, extras: '');
  final parts = _readContent(content);
  final extras = parts.extras.encode();
  return (text: extras.isEmpty ? content : parts.text.trim(), extras: extras);
}

// Read card text without encoding every checklist and table back into JSON
String entryPlainText(String content) {
  if (!_mayHaveStructure(content)) return content;
  final parts = _readContent(content);
  final hasExtras =
      parts.extras.checklists.isNotEmpty ||
      parts.extras.tables.isNotEmpty ||
      parts.extras.lists.isNotEmpty;
  return hasExtras ? parts.text.trim() : content;
}

class EntryContentBlock {
  const EntryContentBlock(this.content, {this.structured = false});
  final String content;
  final bool structured;
}

/// Preserve the order of text and structured blocks, including older saved entries.
List<EntryContentBlock> entryContentBlocks(String content) {
  if (!_mayHaveStructure(content)) return [EntryContentBlock(content)];
  final lines = content.split('\n');
  final hasEncodedBlocks = lines.any(_hasEncodedBlock);
  if (!hasEncodedBlocks) {
    final legacy = splitEntryContent(content);
    if (legacy.extras.isEmpty) return [EntryContentBlock(content)];
    return [
      EntryContentBlock(legacy.text),
      for (final line in legacy.extras.split('\n'))
        EntryContentBlock(line, structured: true),
    ];
  }
  final result = <EntryContentBlock>[];
  final text = <String>[];
  void flush() {
    if (text.isNotEmpty) result.add(EntryContentBlock(text.join('\n')));
    text.clear();
  }

  for (final line in lines) {
    final encoded = _hasEncodedBlock(line)
        ? splitEntryContent(line).extras
        : '';
    if (encoded.isEmpty) {
      text.add(line);
    } else {
      flush();
      result.add(EntryContentBlock(encoded, structured: true));
    }
  }
  flush();
  return result.isEmpty ? [const EntryContentBlock('')] : result;
}

typedef _SearchSummary = ({String text, bool hasChecklist});
final _searchSummaries = <String, _SearchSummary>{};
var _searchSummaryCharacters = 0;
const _searchSummaryBudget = 128 * 1024;

bool entryHasChecklist(String content) =>
    (content.contains(_checklistPrefix) ||
        content.contains('- [ ] ') ||
        content.contains('- [x] ')) &&
    _searchSummary(content).hasChecklist;

String entrySearchText(String content) =>
    _mayHaveStructure(content) ? _searchSummary(content).text : content;

_SearchSummary _searchSummary(String content) {
  final cached = _searchSummaries.remove(content);
  if (cached != null) {
    _searchSummaries[content] = cached;
    return cached;
  }
  final parts = _readContent(content);
  final text = [
    parts.text,
    for (final list in parts.extras.checklists) ...[
      list.title,
      for (final item in list.items) item.text,
    ],
    for (final list in parts.extras.lists) ...[list.title, ...list.items],
    for (final table in parts.extras.tables) ...[
      table.title,
      for (final row in table.rows) ...row,
    ],
  ].where((value) => value.isNotEmpty).join('\n');
  final summary = (
    text: text,
    hasChecklist: parts.extras.checklists.isNotEmpty,
  );
  final size = content.length + text.length;
  if (size <= _searchSummaryBudget ~/ 8) {
    while (_searchSummaries.isNotEmpty &&
        (_searchSummaries.length >= 128 ||
            _searchSummaryCharacters + size > _searchSummaryBudget)) {
      final oldest = _searchSummaries.keys.first;
      _searchSummaryCharacters -=
          oldest.length + _searchSummaries.remove(oldest)!.text.length;
    }
    _searchSummaries[content] = summary;
    _searchSummaryCharacters += size;
  }
  return summary;
}

class EntryDocumentView extends StatelessWidget {
  const EntryDocumentView({super.key, required this.content});
  final String content;

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in entryContentBlocks(content))
          if (block.structured)
            EntryExtras(text: block.content, compact: true)
          else if (block.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                block.content,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
      ],
    ),
  );
}

class EntryExtras extends StatefulWidget {
  const EntryExtras({
    super.key,
    required this.text,
    this.onChanged,
    this.enabled = true,
    this.showToolbar = true,
    this.compact = false,
    this.autofocus = false,
  });

  final String text;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool showToolbar;
  final bool compact;
  final bool autofocus;

  @override
  State<EntryExtras> createState() => _EntryExtrasState();
}

class _EntryExtrasState extends State<EntryExtras> {
  int _fieldIndex = 0;
  late _Extras _extras = _readContent(widget.text).extras;
  bool get _editing => widget.onChanged != null;
  bool get _enabled => _editing && widget.enabled;

  @override
  void didUpdateWidget(covariant EntryExtras oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.text != widget.text) {
      _extras = _readContent(widget.text).extras;
    }
  }

  void _changed() => widget.onChanged?.call(_extras.encode());

  void _update(VoidCallback change) {
    setState(change);
    _changed();
  }

  Widget _field(
    String value,
    String hint,
    ValueChanged<String> change, {
    TextStyle? style,
    double scale = 1,
    bool multiline = false,
    TextAlign textAlign = TextAlign.left,
  }) {
    if (!_editing) return Text(value, style: style, textAlign: textAlign);
    return TextFormField(
      initialValue: value,
      autofocus: widget.autofocus && _fieldIndex++ == 0,
      enableInteractiveSelection: true,
      contextMenuBuilder: (context, state) =>
          AdaptiveTextSelectionToolbar.editableText(editableTextState: state),
      textAlign: textAlign,
      maxLines: multiline ? null : 1,
      keyboardType: multiline ? TextInputType.multiline : null,
      enabled: _enabled,
      style: style,
      decoration: InputDecoration(
        hintText: hint,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 4 * scale),
      ),
      onChanged: (value) {
        change(value);
        _changed();
      },
    );
  }

  Widget _panel({
    required Object key,
    required String title,
    required String hint,
    required ValueChanged<String> rename,
    required VoidCallback remove,
    required List<Widget> children,
  }) => Container(
    key: ObjectKey(key),
    margin: EdgeInsets.only(bottom: widget.compact ? 8 : 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_editing || title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Expanded(
                  child: _field(
                    title,
                    hint,
                    rename,
                    textAlign: [
                      TextAlign.left,
                      TextAlign.center,
                      TextAlign.right,
                    ][_extras.alignments[key] ?? 0],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_editing)
                  PopupMenuButton<int>(
                    tooltip: 'Alignment',
                    enabled: _enabled,
                    icon: Icon(
                      [
                        Icons.format_align_left,
                        Icons.format_align_center,
                        Icons.format_align_right,
                      ][_extras.alignments[key] ?? 0],
                      size: 18,
                    ),
                    onSelected: (value) =>
                        _update(() => _extras.alignments[key] = value),
                    itemBuilder: (_) => [
                      for (var i = 0; i < 3; i++)
                        PopupMenuItem(
                          value: i,
                          child: Text(['Left', 'Center', 'Right'][i]),
                        ),
                    ],
                  ),
                if (_editing)
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: _enabled ? () => _update(remove) : null,
                  ),
              ],
            ),
          ),
        ...children,
      ],
    ),
  );

  Widget _checklist(int index) {
    final checklist = _extras.checklists[index];
    final items = checklist.items;
    return _panel(
      key: items,
      title: checklist.title,
      hint: 'Checklist title',
      rename: (title) =>
          _extras.checklists[index] = (title: title, items: items),
      remove: () => _extras.checklists.removeAt(index),
      children: [
        for (var item = 0; item < items.length; item++)
          Row(
            // Recreate remaining fields when removing an earlier item
            key: ValueKey((items.length, item)),
            children: [
              if (_editing)
                Checkbox(
                  visualDensity: VisualDensity.standard,
                  value: items[item].checked,
                  onChanged: _enabled
                      ? (checked) => _update(() {
                          items[item] = (
                            text: items[item].text,
                            checked: checked ?? false,
                          );
                        })
                      : null,
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 9, bottom: 9),
                  child: Icon(
                    items[item].checked
                        ? Icons.check_box_outlined
                        : Icons.check_box_outline_blank,
                    size: 24,
                    semanticLabel: items[item].checked
                        ? 'Checked'
                        : 'Unchecked',
                  ),
                ),
              Expanded(
                child: _field(
                  items[item].text,
                  'List item',
                  (text) {
                    items[item] = (text: text, checked: items[item].checked);
                  },
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    height: 1.5,
                    decoration: items[item].checked
                        ? TextDecoration.lineThrough
                        : null,
                    color: items[item].checked
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
              ),
              if (_editing)
                IconButton(
                  tooltip: 'Remove item',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: _enabled
                      ? () => _update(() => items.removeAt(item))
                      : null,
                ),
            ],
          ),
        if (_editing)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
              onPressed: _enabled
                  ? () => _update(() => items.add((text: '', checked: false)))
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _table(int index) {
    final table = _extras.tables[index];
    final rows = table.rows;
    final columns = rows.first.length;
    final theme = Theme.of(context);
    return _panel(
      key: rows,
      title: table.title,
      hint: 'Table title',
      rename: (title) => _extras.tables[index] = (title: title, rows: rows),
      remove: () => _extras.tables.removeAt(index),
      children: [
        EntryTableViewport(
          alignment: [
            Alignment.centerLeft,
            Alignment.center,
            Alignment.centerRight,
          ][_extras.alignments[rows] ?? 0],
          builder: (scale) {
            final colors = theme.colorScheme;
            final bodyStyle = theme.textTheme.bodyMedium!.copyWith(
              color: colors.onSurface,
              fontSize: (theme.textTheme.bodyMedium!.fontSize ?? 14) * scale,
            );
            final headerStyle = bodyStyle.copyWith(fontWeight: FontWeight.w700);
            final headerColor = Color.alphaBlend(
              Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.24 : 0.12,
              ),
              colors.surface,
            );
            final widths = <int, TableColumnWidth>{};
            final painter = TextPainter(
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            );
            for (var column = 0; column < columns; column++) {
              var width = 76 * scale;
              for (var row = 0; row < rows.length; row++) {
                painter.text = TextSpan(
                  text: rows[row][column],
                  style: row == 0 ? headerStyle : bodyStyle,
                );
                // Very long cells wrap inside a wide column instead of clipping.
                painter.layout(maxWidth: 1600 * scale);
                width = math.max(width, painter.width + 22 * scale);
              }
              widths[column] = FixedColumnWidth(width.ceilToDouble());
            }
            painter.dispose();

            return Table(
              columnWidths: widths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder.all(color: colors.outlineVariant),
              children: [
                for (var row = 0; row < rows.length; row++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: row == 0 ? headerColor : colors.surface,
                    ),
                    children: [
                      for (var column = 0; column < columns; column++)
                        Padding(
                          key: ValueKey((row, column)),
                          padding: EdgeInsets.symmetric(
                            horizontal: 9 * scale,
                            vertical: 6 * scale,
                          ),
                          child: _field(
                            rows[row][column],
                            '',
                            (value) =>
                                setState(() => rows[row][column] = value),
                            scale: scale,
                            multiline: true,
                            style: row == 0 ? headerStyle : bodyStyle,
                          ),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
        if (_editing)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _stepper(
                  'Rows',
                  rows.length,
                  onRemove: _enabled && rows.length > 1
                      ? () => _removeTableEdge(rows, column: false)
                      : null,
                  onAdd: _enabled
                      ? () => _update(() {
                          rows.add(List.filled(columns, '', growable: true));
                        })
                      : null,
                ),
                _stepper(
                  'Columns',
                  columns,
                  onRemove: _enabled && columns > 1
                      ? () => _removeTableEdge(rows, column: true)
                      : null,
                  onAdd: _enabled
                      ? () => _update(() {
                          for (final row in rows) {
                            row.add('');
                          }
                        })
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Markers are derived from the item position so removals always renumber the list
  static const _markers = {
    'bullet': '• Bullets',
    'dash': '– Dashes',
    'square': '▪ Squares',
    'number': '1. Numbers',
    'lower': 'a. Letters',
    'upper': 'A. Letters',
    'roman': 'I. Roman numerals',
    'none': 'No markers',
  };

  String _marker(String style, int index) {
    if (style == 'number') return '${index + 1}.';
    if (style == 'lower' || style == 'upper') {
      var number = index + 1;
      var label = '';
      while (number > 0) {
        number--;
        label = String.fromCharCode(97 + number % 26) + label;
        number ~/= 26;
      }
      return '${style == 'upper' ? label.toUpperCase() : label}.';
    }
    if (style == 'roman') {
      var number = index + 1;
      var label = '';
      for (final pair in [
        (1000, 'M'),
        (900, 'CM'),
        (500, 'D'),
        (400, 'CD'),
        (100, 'C'),
        (90, 'XC'),
        (50, 'L'),
        (40, 'XL'),
        (10, 'X'),
        (9, 'IX'),
        (5, 'V'),
        (4, 'IV'),
        (1, 'I'),
      ]) {
        while (number >= pair.$1) {
          label += pair.$2;
          number -= pair.$1;
        }
      }
      return '$label.';
    }
    return {'dash': '–', 'square': '▪', 'none': ''}[style] ?? '•';
  }

  Widget _list(int index) {
    final list = _extras.lists[index];
    final items = list.items;
    return _panel(
      key: items,
      title: list.title,
      hint: 'List title',
      rename: (title) => _extras.lists[index] = (
        title: title,
        marker: list.marker,
        items: items,
      ),
      remove: () => _extras.lists.removeAt(index),
      children: [
        if (_editing)
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<String>(
              enabled: _enabled,
              tooltip: 'List markers',
              onSelected: (marker) => _update(
                () => _extras.lists[index] = (
                  title: list.title,
                  marker: marker,
                  items: items,
                ),
              ),
              itemBuilder: (_) => [
                for (final entry in _markers.entries)
                  PopupMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  '${_markers[list.marker] ?? _markers['bullet']}  ▾',
                ),
              ),
            ),
          ),
        for (var item = 0; item < items.length; item++)
          Padding(
            key: ValueKey((items.length, item)),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (list.marker != 'none')
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 4),
                    child: Text(_marker(list.marker, item)),
                  ),
                Expanded(
                  child: _field(
                    items[item],
                    'List item',
                    (value) => items[item] = value,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                if (_editing)
                  IconButton(
                    tooltip: 'Remove item',
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: _enabled
                        ? () => _update(() => items.removeAt(item))
                        : null,
                  ),
              ],
            ),
          ),
        if (_editing)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add item'),
              onPressed: _enabled ? () => _update(() => items.add('')) : null,
            ),
          ),
      ],
    );
  }

  Widget _stepper(
    String label,
    int count, {
    required VoidCallback? onRemove,
    required VoidCallback? onAdd,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Remove last ${label == 'Rows' ? 'row' : 'column'}',
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
          ),
          onPressed: onRemove,
          icon: const Icon(Icons.remove, size: 18),
        ),
        Text('$count', style: Theme.of(context).textTheme.labelLarge),
        IconButton(
          tooltip: 'Add ${label == 'Rows' ? 'row' : 'column'}',
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
          ),
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
  }

  // Remove the last row or column while keeping at least one editable cell
  Future<void> _removeTableEdge(
    List<List<String>> rows, {
    required bool column,
  }) async {
    if (!_enabled || (column ? rows.first.length : rows.length) <= 1) return;
    final cells = column ? rows.map((row) => row.last) : rows.last;
    if (cells.any((cell) => cell.trim().isNotEmpty)) {
      final target = column ? 'column' : 'row';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Remove last $target?'),
          content: Text('The text in this $target will be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true || !_enabled) return;
    }
    if (!_extras.tables.any((table) => identical(table.rows, rows))) return;
    FocusScope.of(context).unfocus();
    _update(() {
      if (column) {
        for (final row in rows) {
          row.removeLast();
        }
      } else {
        rows.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _fieldIndex = 0;
    final checklists = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _extras.checklists.length; index++)
          _checklist(index),
      ],
    );
    final tables = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _extras.tables.length; index++)
          _table(index),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_editing && widget.showToolbar)
          Wrap(
            children: [
              IconButton(
                tooltip: 'Add checklist',
                icon: const Icon(Icons.checklist),
                onPressed: _enabled
                    ? () => _update(() {
                        _extras.checklists.add((
                          title: '',
                          items: [(text: '', checked: false)],
                        ));
                      })
                    : null,
              ),
              IconButton(
                tooltip: 'Add list',
                icon: const Icon(Icons.format_list_bulleted),
                onPressed: _enabled
                    ? () => _update(
                        () => _extras.lists.add((
                          title: '',
                          marker: 'bullet',
                          items: [''],
                        )),
                      )
                    : null,
              ),
              IconButton(
                tooltip: 'Add table',
                icon: const Icon(Icons.table_chart_outlined),
                onPressed: _enabled
                    ? () => _update(() {
                        _extras.tables.add((
                          title: '',
                          rows: List.generate(2, (_) => ['', '']),
                        ));
                      })
                    : null,
              ),
            ],
          ),
        if (_extras.checklists.isNotEmpty) ...[
          if (!widget.compact) const Divider(height: 24),
          checklists,
        ],
        if (_extras.lists.isNotEmpty) ...[
          if (!widget.compact) const Divider(height: 24),
          for (var index = 0; index < _extras.lists.length; index++)
            _list(index),
        ],
        if (_extras.tables.isNotEmpty) ...[
          if (!widget.compact) const Divider(height: 24),
          tables,
        ],
      ],
    );
  }
}
