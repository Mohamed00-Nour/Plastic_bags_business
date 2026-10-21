import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/stock_log_model.dart';

class StockLogsScreen extends StatefulWidget {
  const StockLogsScreen({super.key});

  @override
  State<StockLogsScreen> createState() => _StockLogsScreenState();
}

class _StockLogsScreenState extends State<StockLogsScreen> {
  String _searchQuery = '';
  StockMovementType? _typeFilter;

  String _extractInvoiceNumber(StockLogModel log) {
    final note = log.note?.trim() ?? '';
    if (note.isNotEmpty) {
      // 1. Extract pattern after # (e.g. "Sales invoice #INV-71061203" -> "INV-71061203")
      final hashMatch = RegExp(r'#([A-Za-z0-9\-_]+)').firstMatch(note);
      if (hashMatch != null &&
          hashMatch.group(1) != null &&
          hashMatch.group(1)!.isNotEmpty) {
        return hashMatch.group(1)!.trim();
      }

      // 2. Extract standard invoice/return pattern (e.g. "INV-123456" or "RET-123456")
      final invMatch = RegExp(
        r'(INV-[A-Za-z0-9\-_]+|RET-[A-Za-z0-9\-_]+)',
        caseSensitive: false,
      ).firstMatch(note);
      if (invMatch != null && invMatch.group(1) != null) {
        return invMatch.group(1)!.trim();
      }

      // 3. If note is not '-' and has content, return the note text itself
      if (note != '-') {
        return note;
      }
    }

    if (log.referenceId != null && log.referenceId!.trim().isNotEmpty) {
      return log.referenceId!.trim();
    }
    return '';
  }

  void _copyInvoiceNumber(BuildContext context, StockLogModel log) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final invoiceNumber = _extractInvoiceNumber(log);
    if (invoiceNumber.isEmpty) return;

    Clipboard.setData(ClipboardData(text: invoiceNumber));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isArabic
                    ? 'تم نسخ رقم الفاتورة ($invoiceNumber) إلى الحافظة'
                    : 'Copied invoice number ($invoiceNumber) to clipboard',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final dateFmt = DateFormat('MMM dd, yyyy HH:mm');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hint: isArabic
                      ? 'ابحث باسم المنتج، رقم الفاتورة، أو الملاحظة...'
                      : 'Search by product, invoice #, or note...',
                  onChanged: (query) =>
                      setState(() => _searchQuery = query.toLowerCase().trim()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text(l10n.all),
                  selected: _typeFilter == null,
                  onSelected: (_) => setState(() => _typeFilter = null),
                ),
                const SizedBox(width: 8),
                ...StockMovementType.values.map((type) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_localizedStockType(l10n, type)),
                        selected: _typeFilter == type,
                        onSelected: (_) =>
                            setState(() => _typeFilter = type),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Logs table
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stock_logs')
                  .orderBy('createdAt', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var logs = snapshot.data!.docs
                    .map((d) => StockLogModel.fromFirestore(d))
                    .toList();

                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery;
                  logs = logs.where((l) {
                    final nameMatch =
                        l.productName.toLowerCase().contains(query);
                    final noteMatch =
                        l.note?.toLowerCase().contains(query) ?? false;
                    final refMatch =
                        l.referenceId?.toLowerCase().contains(query) ?? false;
                    final userMatch =
                        l.createdBy.toLowerCase().contains(query);
                    return nameMatch || noteMatch || refMatch || userMatch;
                  }).toList();
                }
                if (_typeFilter != null) {
                  logs =
                      logs.where((l) => l.type == _typeFilter).toList();
                }

                if (logs.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.history,
                    title: l10n.noStockLogsFound,
                    subtitle: l10n.stockMovementHistory,
                  );
                }

                return Card(
                  child: HorizontalScrollableTable(
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(l10n.date)),
                          DataColumn(label: Text(l10n.product)),
                          DataColumn(label: Text(l10n.type)),
                          DataColumn(
                              label: Text(l10n.qty), numeric: true),
                          DataColumn(
                              label: Text(l10n.before), numeric: true),
                          DataColumn(
                              label: Text(l10n.after), numeric: true),
                          DataColumn(label: Text(l10n.note)),
                          DataColumn(label: Text(l10n.createdByLabel)),
                        ],
                        rows: logs.map((log) {
                          Color typeColor;
                          switch (log.type) {
                            case StockMovementType.incoming:
                              typeColor = AppTheme.successColor;
                            case StockMovementType.outgoing:
                              typeColor = AppTheme.dangerColor;
                            case StockMovementType.adjustment:
                              typeColor = AppTheme.warningColor;
                          }

                          final noteText = log.note;
                          final hasNote = noteText != null &&
                              noteText.trim().isNotEmpty &&
                              noteText.trim() != '-';
                          final invNum = _extractInvoiceNumber(log);
                          final canCopy = hasNote && invNum.isNotEmpty;

                          return DataRow(cells: [
                            DataCell(
                                Text(dateFmt.format(log.createdAt))),
                            DataCell(Text(log.productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500))),
                            DataCell(StatusBadge(
                                label: _localizedStockType(l10n, log.type),
                                color: typeColor)),
                            DataCell(Text(
                              '${log.type == StockMovementType.incoming ? '+' : '-'}${formatQuantity(log.quantity)}',
                              style: TextStyle(
                                color: typeColor,
                                fontWeight: FontWeight.w500,
                              ),
                            )),
                            DataCell(Text(formatQuantity(log.stockBefore))),
                            DataCell(Text(formatQuantity(log.stockAfter))),
                            DataCell(
                              !hasNote
                                  ? const Text('-')
                                  : InkWell(
                                      onTap: canCopy
                                          ? () =>
                                              _copyInvoiceNumber(context, log)
                                          : null,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4, horizontal: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              noteText,
                                              style: TextStyle(
                                                color: canCopy
                                                    ? AppTheme.primaryColor
                                                    : null,
                                                fontWeight: canCopy
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            if (canCopy) ...[
                                              const SizedBox(width: 6),
                                              Tooltip(
                                                message: isArabic
                                                    ? 'نسخ رقم الفاتورة ($invNum)'
                                                    : 'Copy invoice number ($invNum)',
                                                child: Icon(
                                                  Icons.copy_rounded,
                                                  size: 14,
                                                  color: AppTheme.primaryColor
                                                      .withValues(alpha: 0.8),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                            DataCell(Text(log.createdBy.isNotEmpty
                                ? log.createdBy
                                : '-')),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _localizedStockType(AppLocalizations l10n, StockMovementType type) {
    switch (type) {
      case StockMovementType.incoming:
        return l10n.stockIncoming;
      case StockMovementType.outgoing:
        return l10n.stockOutgoing;
      case StockMovementType.adjustment:
        return l10n.stockAdjustment;
    }
  }
}
