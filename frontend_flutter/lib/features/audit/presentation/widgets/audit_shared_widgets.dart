import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_data_table.dart';
import '../../../../core/widgets/icare_metric_card.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../../shared/utils/file_download_helper.dart';

class AuditKpiItem {
  final String label;
  final String value;
  final String? delta;
  final bool isInverseDelta;
  final bool highlightEmerald;
  final Color? topBorderColor;
  final IconData? icon;

  const AuditKpiItem(
    this.label,
    this.value, {
    this.delta,
    this.isInverseDelta = false,
    this.highlightEmerald = false,
    this.topBorderColor,
    this.icon,
  });
}

String formatAuditDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

String formatAuditNaira(double val) =>
    CurrencyFormatter.formatNaira(val, showDecimals: true);

void exportAuditCsv(List<Map<String, dynamic>> records, String baseName) {
  if (records.isEmpty) return;
  final clean = records.map((r) {
    final m = <String, dynamic>{};
    r.forEach((k, v) {
      if (!k.endsWith('_Raw') && !k.startsWith('_')) m[k] = v;
    });
    return m;
  }).toList();
  if (clean.isEmpty || clean.first.isEmpty) return;

  final keys = clean.first.keys.toList();
  final buffer = StringBuffer();
  buffer.writeln(keys.map((k) => '"$k"').join(','));
  for (final row in clean) {
    buffer.writeln(keys.map((k) {
      final val = row[k]?.toString() ?? '';
      return '"${val.replaceAll('"', '""')}"';
    }).join(','));
  }
  final bytes = utf8.encode(buffer.toString());
  downloadBlobFile(
    bytes,
    'audit_${baseName}_${formatAuditDate(DateTime.now())}.csv',
    'text/csv',
  );
}

Widget buildAuditErrorCard(
  BuildContext context,
  dynamic error, {
  VoidCallback? onRetry,
}) {
  final tokens = IcareSurfaceTokens.of(context);
  final details = error is AppErrorDetails ? error : AppErrorDetails.from(error);
  return IcareCard(
    topAccentColor: tokens.dangerDot,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 20, color: tokens.dangerDot),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                details.title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.dangerText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                details.message,
                style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
              ),
            ],
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('Retry'),
          ),
        ],
      ],
    ),
  );
}

Widget buildAuditEmptyCard(BuildContext context, String message) {
  final tokens = IcareSurfaceTokens.of(context);
  return IcareCard(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    child: Row(
      children: [
        Icon(Icons.inbox_outlined, size: 20, color: tokens.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 13, color: tokens.textMuted),
          ),
        ),
      ],
    ),
  );
}

Widget buildAuditKpiGrid(List<AuditKpiItem> items) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width >= 960 && items.length <= 5) {
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: IcareMetricCard(
                  label: items[i].label,
                  value: items[i].value,
                  delta: items[i].delta,
                  isInverseDelta: items[i].isInverseDelta,
                  isFullEmerald: items[i].highlightEmerald,
                  topBorderColor: items[i].topBorderColor,
                  icon: items[i].icon,
                ),
              ),
            ],
          ],
        );
      }
      final cols = width >= 660 ? 3 : (width >= 420 ? 2 : 1);
      final cardW = (width - (10 * (cols - 1))) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) {
          return SizedBox(
            width: cardW,
            child: IcareMetricCard(
              label: item.label,
              value: item.value,
              delta: item.delta,
              isInverseDelta: item.isInverseDelta,
              isFullEmerald: item.highlightEmerald,
              topBorderColor: item.topBorderColor,
              icon: item.icon,
            ),
          );
        }).toList(),
      );
    },
  );
}

InputDecoration auditInputDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final tokens = IcareSurfaceTokens.of(context);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    isDense: true,
    hintStyle: TextStyle(fontSize: 12.5, color: tokens.textLight),
    filled: true,
    fillColor: tokens.surfaceSubtle,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: tokens.borderStrong),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: tokens.borderStrong),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5),
    ),
  );
}

Widget buildAuditDatePicker(
  BuildContext context, {
  required String label,
  required DateTime value,
  required ValueChanged<DateTime> onChanged,
}) {
  final tokens = IcareSurfaceTokens.of(context);
  return InkWell(
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime(2023),
        lastDate: DateTime(2035),
      );
      if (picked != null) onChanged(picked);
    },
    borderRadius: BorderRadius.circular(8),
    child: InputDecorator(
      decoration: auditInputDecoration(
        context,
        label: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 15),
      ),
      child: Text(
        formatAuditDate(value),
        style: TextStyle(fontSize: 12.5, color: tokens.textPrimary),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

Widget buildAuditDropdown(
  BuildContext context, {
  required String label,
  required String value,
  required List<String> items,
  required ValueChanged<String> onChanged,
  bool enabled = true,
}) {
  final tokens = IcareSurfaceTokens.of(context);
  final safeItems = items.isEmpty ? [value] : items;
  final effectiveVal = safeItems.contains(value) ? value : safeItems.first;
  return DropdownButtonFormField<String>(
    value: effectiveVal,
    isExpanded: true,
    dropdownColor: tokens.surfaceElevated,
    decoration: auditInputDecoration(context, label: label),
    items: safeItems
        .map(
          (i) => DropdownMenuItem(
            value: i,
            child: Text(i, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
          ),
        )
        .toList(),
    onChanged: enabled
        ? (v) {
            if (v != null) onChanged(v);
          }
        : null,
  );
}

Widget buildAuditSearchField(
  BuildContext context, {
  required String hint,
  required TextEditingController controller,
  required VoidCallback onChangedOrSubmitted,
}) {
  return TextField(
    controller: controller,
    onSubmitted: (_) => onChangedOrSubmitted(),
    onChanged: (_) => onChangedOrSubmitted(),
    decoration: auditInputDecoration(
      context,
      label: 'Search',
      hint: hint,
      prefixIcon: const Icon(Icons.search, size: 16),
      suffixIcon: controller.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, size: 15),
              onPressed: () {
                controller.clear();
                onChangedOrSubmitted();
              },
            )
          : null,
    ),
  );
}

Widget buildAuditFilterCard(
  BuildContext context, {
  required Widget child,
  required void Function(DateTime from, DateTime to)? onDateQuickSelect,
  required bool showCardView,
  required ValueChanged<bool> onToggleView,
}) {
  final tokens = IcareSurfaceTokens.of(context);
  final now = DateTime.now();

  Widget presetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: tokens.surfaceSubtle,
      side: BorderSide(color: tokens.borderSubtle),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: tokens.textSecondary,
      ),
    );
  }

  return IcareCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        if (onDateQuickSelect != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Presets:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
              presetChip('Today', () => onDateQuickSelect(now, now)),
              presetChip(
                '7 Days',
                () => onDateQuickSelect(now.subtract(const Duration(days: 7)), now),
              ),
              presetChip(
                'This Month',
                () => onDateQuickSelect(DateTime(now.year, now.month, 1), now),
              ),
              presetChip(
                '90 Days',
                () => onDateQuickSelect(now.subtract(const Duration(days: 90)), now),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(showCardView ? 'Card View' : 'Table View'),
                avatar: Icon(
                  showCardView
                      ? Icons.view_agenda_outlined
                      : Icons.table_chart_outlined,
                  size: 14,
                ),
                selected: showCardView,
                onSelected: (v) => onToggleView(!showCardView),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

bool _isCurrencyColumn(String col) {
  final l = col.toLowerCase();
  return l.contains('amount') ||
      l.contains('deposit') ||
      l.contains('withdrawal') ||
      l.contains('balance') ||
      l.contains('principal') ||
      l.contains('expected') ||
      l.contains('paid') ||
      l.contains('actual') ||
      l.contains('variance') ||
      l.contains('debit') ||
      l.contains('credit');
}

String formatAuditCellValue(String col, dynamic rawVal) {
  if (rawVal == null) return '-';
  if (rawVal is num && _isCurrencyColumn(col)) {
    return formatAuditNaira(rawVal.toDouble());
  }
  final s = rawVal.toString().trim();
  return s.isEmpty ? '-' : s;
}

Widget buildAuditDataDisplay(
  BuildContext context, {
  required List<Map<String, dynamic>> records,
  required List<String> columns,
  required bool forceCardView,
  String emptyMessage = 'No records match the selected filters.',
}) {
  if (records.isEmpty) {
    return buildAuditEmptyCard(context, emptyMessage);
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 740;
      final useCards = forceCardView || isMobile;
      final tokens = IcareSurfaceTokens.of(context);

      if (useCards) {
        return Column(
          children: records.map((r) {
            final primaryCol = columns.isNotEmpty ? columns.first : 'Record';
            final secondCol = columns.length > 1 ? columns[1] : '';
            final statusVal = r['Status']?.toString() ?? r['status']?.toString();
            final amountKey = columns.firstWhere(
              (c) => _isCurrencyColumn(c) && r[c] != null,
              orElse: () => '',
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IcareCard(
                padding: const EdgeInsets.all(14),
                onTap: () => showAuditRowInspectorSheet(context, r, columns),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${formatAuditCellValue(primaryCol, r[primaryCol])}${secondCol.isNotEmpty ? ' • ${formatAuditCellValue(secondCol, r[secondCol])}' : ''}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (statusVal != null && statusVal.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IcareStatusBadge.fromStatus(statusVal),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: columns
                          .where((c) =>
                              c != primaryCol &&
                              c != secondCol &&
                              c != 'Status' &&
                              c != 'status')
                          .take(5)
                          .map((c) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              c.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: tokens.textMuted,
                              ),
                            ),
                            Text(
                              formatAuditCellValue(c, r[c]),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: c == amountKey
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: c == amountKey
                                    ? tokens.brandPrimary
                                    : tokens.textSecondary,
                                fontFeatures: _isCurrencyColumn(c)
                                    ? const [FontFeature.tabularFigures()]
                                    : null,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Tap to inspect',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tokens.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: tokens.brandPrimary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      }

      return IcareDataTable(
        minWidth: math.max(constraints.maxWidth - 4, columns.length * 115.0),
        columns: [
          ...columns.map(
            (c) => DataColumn(
              label: Text(c),
              numeric: _isCurrencyColumn(c),
            ),
          ),
          const DataColumn(label: Text('Inspect')),
        ],
        rows: records.map((r) {
          return DataRow(
            cells: [
              ...columns.map((c) {
                final valStr = formatAuditCellValue(c, r[c]);
                if (c.toLowerCase() == 'status') {
                  return DataCell(IcareStatusBadge.fromStatus(valStr));
                }
                return DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 210),
                    child: Text(
                      valStr,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: _isCurrencyColumn(c)
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontFeatures: _isCurrencyColumn(c)
                            ? const [FontFeature.tabularFigures()]
                            : null,
                      ),
                    ),
                  ),
                );
              }),
              DataCell(
                IconButton(
                  tooltip: 'Inspect Record Details',
                  icon: Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: tokens.brandPrimary,
                  ),
                  onPressed: () => showAuditRowInspectorSheet(context, r, columns),
                ),
              ),
            ],
          );
        }).toList(),
      );
    },
  );
}

Future<void> showAuditRowInspectorSheet(
  BuildContext context,
  Map<String, dynamic> row,
  List<String> preferredColumns,
) async {
  bool showRaw = false;
  await showIcareAdaptiveSheet<void>(
    context: context,
    builder: (sheetCtx, isDialog) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final tokens = IcareSurfaceTokens.of(sheetCtx);
          final displayEntries = <MapEntry<String, String>>[];
          for (final col in preferredColumns) {
            if (row.containsKey(col)) {
              displayEntries.add(
                MapEntry(col, formatAuditCellValue(col, row[col])),
              );
            }
          }
          if (displayEntries.isEmpty) {
            row.forEach((k, v) {
              if (!k.startsWith('_')) {
                displayEntries.add(MapEntry(k, formatAuditCellValue(k, v)));
              }
            });
          }

          return Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tokens.surfaceElevated,
                borderRadius: isDialog
                    ? BorderRadius.circular(16)
                    : const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fact_check_outlined,
                            size: 20, color: tokens.brandPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Transaction Record Inspector',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                    Divider(color: tokens.borderSubtle, height: 22),
                    ...displayEntries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 140,
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textMuted,
                                ),
                              ),
                            ),
                            Expanded(
                              child: entry.key.toLowerCase() == 'status'
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: IcareStatusBadge.fromStatus(
                                          entry.value),
                                    )
                                  : Text(
                                      entry.value,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (row['_raw_record'] is Map) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Show Underlying Record Snapshot',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.textSecondary,
                          ),
                        ),
                        value: showRaw,
                        onChanged: (v) => setSheetState(() => showRaw = v),
                      ),
                      if (showRaw)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tokens.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: SelectableText(
                            const JsonEncoder.withIndent('  ')
                                .convert(row['_raw_record']),
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
