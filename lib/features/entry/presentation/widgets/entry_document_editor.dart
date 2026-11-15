import 'package:flutter_application_1/l10n/app_localizations.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import 'entry_formatted_content.dart';

class EntryDocumentController extends ChangeNotifier {
  EntryDocumentController({String text = ''}) : _initial = text, _draft = text;

  String _initial;
  String _draft;
  Iterable<String> Function()? _segments;
  List<String>? _baseline;
  bool _isDirty = false;

  bool get isDirty => _isDirty;
  String get text =>
      _isDirty ? _segments?.call().join('\n') ?? _draft : _initial;

  List<String> _attach(Iterable<String> Function() segments) {
    _segments = segments;
    return _baseline ??= segments().toList();
  }

  void _changed({required bool differsFromBaseline}) {
    _isDirty = differsFromBaseline;
    notifyListeners();
  }

  void _detach() {
    _draft = text;
    _segments = null;
  }

  void markSaved(String text) {
    _initial = _draft = text;
    final segments = _segments;
    if (segments == null) {
      _baseline = null;
    } else {
      _baseline!
        ..clear()
        ..addAll(segments());
    }
    _isDirty = false;
    notifyListeners();
  }
}

const _plainDecoration = InputDecoration(
  filled: false,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  contentPadding: EdgeInsets.zero,
);

class EntryTitleField extends StatelessWidget {
  const EntryTitleField({
    super.key,
    required this.controller,
    required this.enabled,
    this.style,
    this.focusNode,
  });
  final TextEditingController controller;
  final bool enabled;
  final TextStyle? style;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle =
        style ??
        theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700);
    return TextFormField(
      key: const Key('entry-title'),
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      enableInteractiveSelection: true,
      contextMenuBuilder: (context, state) =>
          AdaptiveTextSelectionToolbar.editableText(editableTextState: state),
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.next,
      style: titleStyle,
      minLines: 1,
      maxLines: 3,
      decoration: _plainDecoration.copyWith(
        hintText: AppLocalizations.of(context)!.entryTitle,
        hintStyle: titleStyle?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? AppLocalizations.of(context)!.enterAnEntryTitle
          : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}

class _DocumentSegment {
  _DocumentSegment.text(String value)
    : text = TextEditingController(text: value),
      encoded = '';
  _DocumentSegment.structured(this.encoded) : text = null;
  final key = GlobalKey();
  final TextEditingController? text;
  final focus = FocusNode();
  String encoded;
  bool autofocus = false;
  bool get isText => text != null;
  String get value => text?.text ?? encoded;
  void dispose() {
    text?.dispose();
    focus.dispose();
  }
}

/// A single editing surface with ordered text and embedded blocks.
/// Structured content keeps the existing on-disk format and private text stays encrypted.
class EntryDocumentEditor extends StatefulWidget {
  const EntryDocumentEditor({
    super.key,
    this.title,
    this.titleFieldKey,
    this.titleFocus,
    required this.content,
    required this.privateOpen,
    required this.onTogglePrivate,
    this.enabled = true,
  });
  final TextEditingController? title;
  final GlobalKey? titleFieldKey;
  final FocusNode? titleFocus;
  final EntryDocumentController content;
  final bool privateOpen;
  final VoidCallback onTogglePrivate;
  final bool enabled;

  @override
  State<EntryDocumentEditor> createState() => _EntryDocumentEditorState();
}

class _EntryDocumentEditorState extends State<EntryDocumentEditor> {
  final _segments = <_DocumentSegment>[];
  final _retired = <_DocumentSegment>[];
  _DocumentSegment? _active;
  late final GlobalKey _firstTextKey;
  late final List<String> _baseline;

  @override
  void initState() {
    super.initState();
    for (final block in entryContentBlocks(widget.content.text)) {
      _segments.add(
        block.structured
            ? _DocumentSegment.structured(block.content)
            : _text(block.content),
      );
    }
    if (_segments.isEmpty || !_segments.first.isText) {
      _segments.insert(0, _text(''));
    }
    if (!_segments.last.isText) _segments.add(_text(''));
    _active = _segments.first;
    _firstTextKey = _segments.first.key;
    _baseline = widget.content._attach(
      () => _segments.map((segment) => segment.value),
    );
  }

  _DocumentSegment _text(String value) {
    final segment = _DocumentSegment.text(value);
    var lastText = value;
    segment.text!.addListener(() {
      if (segment.text!.text == lastText) return;
      lastText = segment.text!.text;
      _publish();
    });
    return segment;
  }

  void _publish() {
    // A keystroke only checks for changes. Serialization happens when the draft is read.
    widget.content._changed(differsFromBaseline: !_matchesBaseline());
  }

  bool _matchesBaseline() {
    if (_segments.length != _baseline.length) return false;
    for (var index = 0; index < _segments.length; index++) {
      if (_segments[index].value != _baseline[index]) return false;
    }
    return true;
  }

  void _insert(String kind) {
    if (!widget.enabled) return;
    final data = switch (kind) {
      'checklist' => {
        'title': '',
        'items': [
          {'text': '', 'checked': false},
        ],
      },
      'list' => {
        'title': '',
        'marker': 'bullet',
        'items': [''],
      },
      _ => {
        'title': '',
        'rows': [
          ['', ''],
          ['', ''],
        ],
      },
    };
    final block = _DocumentSegment.structured(
      '::entry-$kind ${jsonEncode(data)}',
    )..autofocus = true;
    final current = _segments.contains(_active) ? _active! : _segments.last;
    final index = _segments.indexOf(current);
    setState(() {
      if (current.isText) {
        final controller = current.text!;
        final offset = controller.selection.isValid
            ? controller.selection.extentOffset.clamp(0, controller.text.length)
            : controller.text.length;
        final before = controller.text.substring(0, offset);
        final after = controller.text.substring(offset);
        // Update the field before adding segments; publish the complete document afterwards.
        controller.value = TextEditingValue(
          text: before,
          selection: TextSelection.collapsed(offset: before.length),
        );
        _segments.insertAll(index + 1, [block, _text(after)]);
      } else {
        // The following paragraph is already available after the new block.
        _segments.insert(index + 1, block);
      }
      _active = block;
    });
    _publish();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || block.key.currentContext == null) return;
      Scrollable.ensureVisible(
        block.key.currentContext!,
        duration: const Duration(milliseconds: 220),
        alignment: 0.5,
      );
    });
  }

  void _changeBlock(_DocumentSegment segment, String value) {
    if (value.isEmpty) {
      setState(() {
        final index = _segments.indexOf(segment);
        _segments.removeAt(index);
        _retired.add(segment);
        _mergeParagraphsAt(index);
        if (!_segments.contains(_active)) _active = _segments.last;
      });
    } else {
      segment.encoded = value;
    }
    _publish();
  }

  void _mergeParagraphsAt(int index) {
    if (index == 0 || index == _segments.length) return;
    final left = _segments[index - 1];
    final right = _segments[index];
    if (!left.isText || !right.isText) return;
    final keepRight = right.focus.hasFocus;
    final keep = keepRight ? right : left;
    final discard = keepRight ? left : right;
    final separator = left.value.isNotEmpty && right.value.isNotEmpty
        ? '\n'
        : '';
    final selection = keep.text!.selection;
    final shift = keepRight ? left.value.length + separator.length : 0;
    final merged = left.value + separator + right.value;
    _segments.remove(discard);
    _retired.add(discard);
    if (_active == discard) _active = keep;
    keep.text!.value = TextEditingValue(
      text: merged,
      selection: selection.isValid
          ? TextSelection(
              baseOffset: selection.baseOffset + shift,
              extentOffset: selection.extentOffset + shift,
              affinity: selection.affinity,
              isDirectional: selection.isDirectional,
            )
          : TextSelection.collapsed(offset: merged.length),
    );
  }

  @override
  void dispose() {
    widget.content._detach();
    for (final segment in [..._segments, ..._retired]) {
      segment.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor ?? colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.title case final title?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: EntryTitleField(
                key: widget.titleFieldKey,
                controller: title,
                enabled: widget.enabled,
                focusNode: widget.titleFocus,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final segment in _segments)
                  Focus(
                    key: segment.key,
                    focusNode: segment.focus,
                    onFocusChange: (focused) {
                      if (focused) _active = segment;
                    },
                    child: segment.isText
                        ? TextField(
                            key: segment.key == _firstTextKey
                                ? const Key('entry-content')
                                : ValueKey(segment),
                            controller: segment.text,
                            enabled: widget.enabled,
                            minLines: _segments.length == 1 ? 5 : 1,
                            maxLines: null,
                            enableInteractiveSelection: true,
                            contextMenuBuilder: (context, state) =>
                                AdaptiveTextSelectionToolbar.editableText(
                                  editableTextState: state,
                                ),
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            style: theme.textTheme.bodyLarge,
                            decoration: _plainDecoration.copyWith(
                              hintText: _segments.length == 1
                                  ? AppLocalizations.of(context)!.entryText
                                  : segment == _segments.last
                                  ? AppLocalizations.of(context)!
                                        .continueWriting
                                  : null,
                            ),
                          )
                        : Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.outlineVariant),
                            ),
                            child: EntryExtras(
                              text: segment.encoded,
                              showToolbar: false,
                              compact: true,
                              autofocus: segment.autofocus,
                              enabled: widget.enabled,
                              onChanged: (value) =>
                                  _changeBlock(segment, value),
                            ),
                          ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Wrap(
              children: [
                IconButton(
                  tooltip: AppLocalizations.of(context)!.addChecklist,
                  onPressed: widget.enabled ? () => _insert('checklist') : null,
                  icon: const Icon(Icons.checklist),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.addList,
                  onPressed: widget.enabled ? () => _insert('list') : null,
                  icon: const Icon(Icons.format_list_bulleted),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.addTable,
                  onPressed: widget.enabled ? () => _insert('table') : null,
                  icon: const Icon(Icons.table_chart_outlined),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.privateInformation,
                  isSelected: widget.privateOpen,
                  onPressed: widget.enabled ? widget.onTogglePrivate : null,
                  icon: const Icon(Icons.lock_outline),
                  selectedIcon: Icon(
                    Icons.lock_open_outlined,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
