import 'package:flutter/material.dart';
import '../theme/icare_typography.dart';
import '../theme/icare_spacing.dart';
import '../theme/icare_theme_tokens.dart';

/// Institutional Banking Data Table
/// Features persistent horizontal scrollbar, zebra striping, and clean typography.
class IcareDataTable extends StatefulWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final bool zebra;
  final String? emptyMessage;
  final double minWidth;

  const IcareDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.zebra = true,
    this.emptyMessage,
    this.minWidth = 600,
  });

  @override
  State<IcareDataTable> createState() => _IcareDataTableState();
}

class _IcareDataTableState extends State<IcareDataTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);

    if (widget.rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: IcareSpacing.roundedMd,
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Center(
          child: Text(
            widget.emptyMessage ?? 'No records available.',
            style: IcareTypography.body.copyWith(color: tokens.textMuted),
          ),
        ),
      );
    }

    // Apply zebra striping if requested
    final styledRows = widget.rows.asMap().entries.map((entry) {
      final index = entry.key;
      final row = entry.value;

      final isEven = index % 2 == 0;
      final zebraAlt = tokens.isDark ? tokens.surfaceSubtle : const Color(0xFFFBFDFA);
      final defaultBg = isEven ? tokens.surface : (widget.zebra ? zebraAlt : tokens.surface);

      return DataRow(
        key: row.key,
        selected: row.selected,
        onSelectChanged: row.onSelectChanged,
        color: row.color ?? WidgetStatePropertyAll(defaultBg),
        cells: row.cells,
      );
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: IcareSpacing.roundedMd,
        border: Border.all(color: tokens.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: tokens.isDark ? const Color(0x20000000) : const Color(0x060F172A),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        thickness: 5,
        radius: const Radius.circular(3),
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: widget.minWidth),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(tokens.canvas),
              headingRowHeight: 40,
              dataRowMinHeight: 42,
              dataRowMaxHeight: 52,
              horizontalMargin: 16,
              columnSpacing: 18,
              headingTextStyle: IcareTypography.tableHeader.copyWith(color: tokens.textSecondary),
              dataTextStyle: IcareTypography.body.copyWith(color: tokens.textSecondary),
              border: TableBorder(
                horizontalInside: BorderSide(color: tokens.borderSubtle, width: 0.8),
              ),
              columns: widget.columns,
              rows: styledRows,
            ),
          ),
        ),
      ),
    );
  }
}
