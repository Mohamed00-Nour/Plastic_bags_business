import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/order_model.dart';
import '../../../../data/models/product_model_new.dart';
import '../../../../data/models/transaction_model.dart';
import '../../bloc/report_bloc_new.dart';
import '../../bloc/report_event.dart';
import '../../bloc/report_state.dart';
import '../../services/pdf_service.dart';
import '../widgets/report_preview_dialog.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    context.read<ReportBloc>().add(ReportLoadRequested(
          startDate: _dateRange.start,
          endDate: _dateRange.end,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateFmt = DateFormat('MMM dd, yyyy');
    return BlocBuilder<ReportBloc, ReportState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Date range picker & PDF buttons
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _pickDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${dateFmt.format(_dateRange.start)} - ${dateFmt.format(_dateRange.end)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: state is ReportLoaded
                            ? () => _showSalesReportPreview(state)
                            : null,
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: Text(l10n.salesReport),
                      ),
                      OutlinedButton.icon(
                        onPressed: state is ReportLoaded
                            ? () => _showInventoryReportPreview()
                            : null,
                        icon: const Icon(Icons.inventory, size: 18),
                        label: Text(l10n.inventoryReport),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showShopStatementPicker(),
                        icon: const Icon(Icons.store, size: 18),
                        label: Text(l10n.shopStatement),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showSupplierInvoicePicker(),
                        icon: const Icon(Icons.local_shipping, size: 18),
                        label: Text(l10n.supplierInvoice),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildContent(state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ReportState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state is ReportLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is ReportLoaded) {
      final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KPI Row
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900
                    ? 4
                    : constraints.maxWidth > 600
                        ? 2
                        : 1;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _KpiCard(
                      title: l10n.totalOrders,
                      value: '${state.orderCount}',
                      icon: Icons.receipt_long,
                      color: AppTheme.primaryColor,
                    ),
                    _KpiCard(
                      title: l10n.totalSales,
                      value: currFmt.format(state.totalSales),
                      icon: Icons.attach_money,
                      color: AppTheme.successColor,
                    ),
                    _KpiCard(
                      title: l10n.balanceCharges,
                      value: currFmt.format(state.totalCharges),
                      icon: Icons.account_balance_wallet,
                      color: AppTheme.infoColor,
                    ),
                    _KpiCard(
                      title: l10n.approvedOrders,
                      value: '${state.approvedCount}',
                      icon: Icons.swap_horiz,
                      color: AppTheme.warningColor,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Daily Sales Chart
            if (state.dailySales.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.dailySales,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod,
                                    rodIndex) {
                                  final entry = state.dailySales.entries
                                      .toList()[group.x.toInt()];
                                  return BarTooltipItem(
                                    '${entry.key}\n\$${rod.toY.toStringAsFixed(2)}',
                                    const TextStyle(color: Colors.white),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final entries =
                                        state.dailySales.entries.toList();
                                    if (value.toInt() >= entries.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return SideTitleWidget(
                                      meta: meta,
                                      child: Text(
                                        entries[value.toInt()].key,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 60,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '\$${value.toInt()}',
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(
                              show: true,
                              drawVerticalLine: false,
                            ),
                            barGroups: state.dailySales.entries
                                .toList()
                                .asMap()
                                .entries
                                .map((entry) {
                              return BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value.value,
                                    color: AppTheme.primaryColor,
                                    width: 16,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            // Recent Orders Table
            if (state.orders.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.ordersInPeriod,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text(l10n.orderId)),
                            DataColumn(label: Text(l10n.shop)),
                            DataColumn(label: Text(l10n.total), numeric: true),
                            DataColumn(label: Text(l10n.status)),
                            DataColumn(label: Text(l10n.date)),
                          ],
                          rows: state.orders.take(20).map((order) {
                            return DataRow(cells: [
                              DataCell(Text(
                                  '#${order.id.substring(0, 8)}')),
                              DataCell(Text(order.shopName)),
                              DataCell(Text(currFmt.format(order.totalPrice))),
                              DataCell(StatusBadge(
                                  label: _localizedOrderStatus(l10n, order.status),
                                  color: order.status == OrderStatus.approved
                                      ? AppTheme.successColor
                                      : order.status == OrderStatus.pending
                                          ? AppTheme.warningColor
                                          : order.status == OrderStatus.rejected
                                              ? AppTheme.dangerColor
                                              : AppTheme.infoColor)),
                              DataCell(Text(
                                DateFormat('MMM dd')
                                    .format(order.createdAt),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (state is ReportError) {
      return Center(child: Text('Error: ${state.message}'));
    }
    return const SizedBox.shrink();
  }

  String _localizedOrderStatus(AppLocalizations l10n, OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return l10n.statusPending;
      case OrderStatus.approved:
        return l10n.statusApproved;
      case OrderStatus.rejected:
        return l10n.statusRejected;
      case OrderStatus.delivered:
        return l10n.statusDelivered;
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadReport();
    }
  }

  Future<void> _showSalesReportPreview(ReportLoaded state) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog(
      context: context,
      builder: (_) => ReportPreviewDialog(
        title: l10n.salesReport,
        buildPdf: (_) => PdfService.buildSalesReportBytes(
          orders: state.orders,
          transactions: state.transactions,
          startDate: _dateRange.start,
          endDate: _dateRange.end,
          totalSales: state.totalSales,
          totalCharges: state.totalCharges,
        ),
      ),
    );
  }

  Future<void> _showInventoryReportPreview() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog(
      context: context,
      builder: (_) => ReportPreviewDialog(
        title: l10n.inventoryReport,
        buildPdf: (_) => PdfService.buildInventoryReportBytes(),
      ),
    );
  }

  void _showShopStatementPicker() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.selectShop),
        content: SizedBox(
          width: 400,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .where('isActive', isEqualTo: true)
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final shops = snapshot.data!.docs;
              if (shops.isEmpty) {
                return Center(child: Text(l10n.noShopsFound));
              }
              return ListView.builder(
                itemCount: shops.length,
                itemBuilder: (context, index) {
                  final data =
                      shops[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.store),
                    title: Text(data['name'] ?? ''),
                    subtitle: Text(data['phone'] ?? ''),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showShopStatementPreview(
                        shops[index].id,
                        data['name'] ?? '',
                        (data['balance'] ?? 0).toDouble(),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _showShopStatementPreview(
      String shopId, String shopName, double balance) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog(
      context: context,
      builder: (_) => ReportPreviewDialog(
        title: l10n.shopStatementFor(shopName),
        buildPdf: (_) async {
          final snapshot = await FirebaseFirestore.instance
              .collection('transactions')
              .where('shopId', isEqualTo: shopId)
              .orderBy('createdAt', descending: true)
              .limit(100)
              .get();
          final transactions = snapshot.docs
              .map((d) => TransactionModel.fromFirestore(d))
              .toList();
          return PdfService.buildShopStatementBytes(
            shopId: shopId,
            shopName: shopName,
            transactions: transactions,
            currentBalance: balance,
          );
        },
      ),
    );
  }

  void _showSupplierInvoicePicker() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.selectSupplier),
        content: SizedBox(
          width: 400,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('suppliers')
                .where('isActive', isEqualTo: true)
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final suppliers = snapshot.data!.docs;
              if (suppliers.isEmpty) {
                return Center(child: Text(l10n.noSuppliersFound));
              }
              return ListView.builder(
                itemCount: suppliers.length,
                itemBuilder: (context, index) {
                  final data =
                      suppliers[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.local_shipping),
                    title: Text(data['name'] ?? ''),
                    subtitle: Text(data['phone'] ?? ''),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSupplierInvoicePreview(
                        suppliers[index].id,
                        data['name'] ?? '',
                        (data['balance'] ?? 0).toDouble(),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupplierInvoicePreview(
      String supplierId, String supplierName, double balance) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog(
      context: context,
      builder: (_) => ReportPreviewDialog(
        title: l10n.supplierInvoiceFor(supplierName),
        buildPdf: (_) async {
          final results = await Future.wait([
            FirebaseFirestore.instance
                .collection('transactions')
                .where('supplierId', isEqualTo: supplierId)
                .orderBy('createdAt', descending: true)
                .limit(100)
                .get(),
            FirebaseFirestore.instance
                .collection('products')
                .where('supplierId', isEqualTo: supplierId)
                .where('isActive', isEqualTo: true)
                .get(),
          ]);
          final transactions = (results[0] as QuerySnapshot).docs
              .map((d) => TransactionModel.fromFirestore(d))
              .toList();
          final products = (results[1] as QuerySnapshot).docs
              .map((d) => ProductModel.fromFirestore(d))
              .toList();
          return PdfService.buildSupplierInvoiceBytes(
            supplierId: supplierId,
            supplierName: supplierName,
            transactions: transactions,
            products: products,
            currentBalance: balance,
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
