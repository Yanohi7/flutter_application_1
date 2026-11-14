// Provide horizontal navigation and independent display zoom for each entry table

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class EntryTableViewport extends StatefulWidget {
  const EntryTableViewport({
    super.key,
    required this.builder,
    this.alignment = Alignment.centerLeft,
  });

  final Alignment alignment;
  final Widget Function(double scale) builder;

  @override
  State<EntryTableViewport> createState() => _EntryTableViewportState();
}

class _EntryTableViewportState extends State<EntryTableViewport> {
  final _scrollController = ScrollController();
  int _zoomPercent = 100;
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: AppLocalizations.of(context)!.zoomOut,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.remove, size: 18),
                onPressed: _zoomPercent > 25
                    ? () => setState(() => _zoomPercent -= 5)
                    : null,
              ),
              Tooltip(
                message: AppLocalizations.of(context)!.resetZoom,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() => _zoomPercent = 100),
                  child: Text('$_zoomPercent%'),
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.zoomIn,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.add, size: 18),
                onPressed: _zoomPercent < 150
                    ? () => setState(() => _zoomPercent += 5)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // A scrollbar gives mouse users a drag target without intercepting cell selection.
        LayoutBuilder(
          builder: (context, constraints) => ScrollConfiguration(
            behavior: behavior.copyWith(
              scrollbars: false,
              dragDevices: {...behavior.dragDevices}
                ..remove(PointerDeviceKind.mouse),
            ),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _scrollController,
                primary: false,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Align(
                    alignment: widget.alignment,
                    widthFactor: 1,
                    child: widget.builder(_zoomPercent / 100),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
