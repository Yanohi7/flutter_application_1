// Let each category row scroll horizontally with mouse or touch dragging and no scrollbar

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// Every category level supports mouse and touch dragging without a scrollbar
class CategoryChipRow extends StatelessWidget {
  final List<Widget> children;

  const CategoryChipRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        // Retain the platform drag devices and add desktop mouse dragging
        dragDevices: {
          ...ScrollConfiguration.of(context).dragDevices,
          PointerDeviceKind.mouse,
        },
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final child in children)
              Padding(padding: const EdgeInsets.only(right: 8), child: child),
          ],
        ),
      ),
    );
  }
}
