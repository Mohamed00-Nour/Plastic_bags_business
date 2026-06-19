import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  hint: l10n.searchByProductName,
                  onChanged: (query) =>
                      setState(() => _searchQuery = query.toLowerCase()),
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
                  logs = logs
                      .where((l) => l.productName
                          .toLowerCase()
                          .contains(_searchQuery))
                      .toList();
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
                              '${log.type == StockMovementType.incoming ? '+' : '-'}${log.quantity}',
                              style: TextStyle(
                                color: typeColor,
                                fontWeight: FontWeight.w500,
                              ),
                            )),
                            DataCell(Text('${log.stockBefore}')),
                            DataCell(Text('${log.stockAfter}')),
                            DataCell(Text(log.note ?? '-')),
                            DataCell(Text(log.createdBy.isNotEmpty ? log.createdBy : '-')),
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
