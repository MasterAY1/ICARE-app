import 'package:flutter/material.dart';

/// Content-width breakpoints for the Admin Dashboard.
/// Evaluated against the actual available layout width (via [LayoutBuilder]),
/// not the raw device screen width, so sidebars and split views are respected.
enum AdminSize {
  /// Phone / narrow viewport (< 600px content width)
  compact,

  /// Tablet / small laptop (600px – 1023px content width)
  medium,

  /// Desktop / wide monitor (>= 1024px content width)
  expanded,
}

extension AdminSizeX on AdminSize {
  bool get isCompact => this == AdminSize.compact;
  bool get isMedium => this == AdminSize.medium;
  bool get isExpanded => this == AdminSize.expanded;
}

AdminSize adminSizeOfWidth(double maxWidth) {
  if (maxWidth < 600) return AdminSize.compact;
  if (maxWidth < 1024) return AdminSize.medium;
  return AdminSize.expanded;
}

AdminSize adminSizeOf(BoxConstraints constraints) =>
    adminSizeOfWidth(constraints.maxWidth);

/// Centers Admin Dashboard content with a 1280px max width and adaptive padding.
class AdminResponsiveContainer extends StatelessWidget {
  final Widget Function(BuildContext context, AdminSize size, double maxWidth)
      builder;
  final EdgeInsetsGeometry? padding;

  const AdminResponsiveContainer({
    super.key,
    required this.builder,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final size = adminSizeOfWidth(availableWidth);
        final horizontalPad = size.isCompact
            ? 12.0
            : size.isMedium
                ? 18.0
                : 24.0;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: padding ??
                  EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 14),
              child: LayoutBuilder(
                builder: (innerCtx, innerConstraints) {
                  final innerW = innerConstraints.maxWidth.isFinite
                      ? innerConstraints.maxWidth
                      : availableWidth;
                  return builder(innerCtx, adminSizeOfWidth(innerW), innerW);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A responsive multi-column grid that sizes rows naturally to their content
/// without a rigid aspect ratio, preventing text clipping at any font scale.
class AdminResponsiveGrid extends StatelessWidget {
  final int columns;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final List<Widget> children;

  const AdminResponsiveGrid({
    super.key,
    required this.columns,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final safeCols = columns.clamp(1, 6);
    if (safeCols == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: mainAxisSpacing),
            children[i],
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += safeCols) {
      final rowChildren = <Widget>[];
      for (int c = 0; c < safeCols; c++) {
        if (c > 0) {
          rowChildren.add(SizedBox(width: crossAxisSpacing));
        }
        final idx = i + c;
        if (idx < children.length) {
          rowChildren.add(Expanded(child: children[idx]));
        } else {
          rowChildren.add(const Expanded(child: SizedBox.shrink()));
        }
      }
      if (rows.isNotEmpty) {
        rows.add(SizedBox(height: mainAxisSpacing));
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rowChildren,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
