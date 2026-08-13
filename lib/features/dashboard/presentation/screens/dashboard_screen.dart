import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/stats_card.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../bloc/dashboard_bloc.dart';
import '../../bloc/dashboard_event.dart';
import '../../bloc/dashboard_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(DashboardLoadRequested());
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppTheme.primaryColor,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null && context.mounted) {
      context.read<DashboardBloc>().add(
            DashboardCustomRangeChanged(
              start: picked.start,
              end: picked.end,
            ),
          );
    }
  }

  String _localizedRangeLabel(AppLocalizations l10n, DashboardDateRange range, bool isArabic) {
    switch (range) {
      case DashboardDateRange.today:
        return isArabic ? 'اليوم' : 'Today';
      case DashboardDateRange.week:
        return isArabic ? 'هذا الأسبوع' : 'This Week';
      case DashboardDateRange.month:
        return isArabic ? 'هذا الشهر' : 'This Month';
      case DashboardDateRange.year:
        return isArabic ? 'هذه السنة' : 'This Year';
      case DashboardDateRange.all:
        return isArabic ? 'الكل' : 'All Time';
      case DashboardDateRange.custom:
        return isArabic ? 'نطاق مخصص' : 'Custom Range';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is DashboardError) {
          return EmptyStateWidget(
            icon: Icons.error_outline,
            title: l10n.failedToLoadDashboard,
            subtitle: state.message,
            action: ElevatedButton(
              onPressed:
                  () => context.read<DashboardBloc>().add(
                    DashboardRefreshRequested(),
                  ),
              child: Text(l10n.retry),
            ),
          );
        }
        if (state is DashboardLoaded) {
          return _buildDashboard(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildDashboard(BuildContext context, DashboardLoaded state) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DashboardBloc>().add(DashboardRefreshRequested());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'نظرة عامة' : l10n.overview,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (state.selectedRange == DashboardDateRange.custom &&
                        state.customStart != null &&
                        state.customEnd != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${DateFormat('yyyy/MM/dd').format(state.customStart!)} – ${DateFormat('yyyy/MM/dd').format(state.customEnd!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: l10n.refresh,
                  onPressed: () => context
                      .read<DashboardBloc>()
                      .add(DashboardRefreshRequested()),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Range Filter Pills ─────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...DashboardDateRange.values
                      .where((r) => r != DashboardDateRange.custom)
                      .map((range) {
                    final isSelected = state.selectedRange == range;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _RangePill(
                        label: _localizedRangeLabel(l10n, range, isArabic),
                        selected: isSelected,
                        onTap: () => context
                            .read<DashboardBloc>()
                            .add(DashboardFilterChanged(range)),
                      ),
                    );
                  }),
                  _RangePill(
                    label: isArabic ? 'نطاق مخصص' : l10n.customRange,
                    selected: state.selectedRange == DashboardDateRange.custom,
                    icon: Icons.date_range_rounded,
                    onTap: () => _pickCustomRange(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Commercial ERP KPI Stats Grid ─────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount =
                    constraints.maxWidth > 1100
                        ? 4
                        : constraints.maxWidth > 650
                        ? 2
                        : 1;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.6,
                  children: [
                    StatsCard(
                      title: isArabic ? 'إجمالي المبيعات التجاري' : 'Commercial Sales',
                      value: currencyFormat.format(state.totalSalesRevenue),
                      icon: Icons.point_of_sale_rounded,
                      color: AppTheme.successColor,
                    ),
                    StatsCard(
                      title: isArabic ? 'إجمالي المقبوضات النقدية' : 'Cash Collected',
                      value: currencyFormat.format(state.totalCashCollected),
                      icon: Icons.payments_rounded,
                      color: const Color(0xFF10B981),
                    ),
                    StatsCard(
                      title: isArabic ? 'إجمالي المشتريات' : 'Commercial Purchases',
                      value: currencyFormat.format(state.totalPurchasesAmount),
                      icon: Icons.shopping_bag_rounded,
                      color: Colors.purple,
                    ),
                    StatsCard(
                      title: isArabic ? 'مرتجعات المبيعات' : 'Sales Returns',
                      value: currencyFormat.format(state.totalReturnsAmount),
                      icon: Icons.assignment_return_rounded,
                      color: Colors.orange,
                    ),
                    StatsCard(
                      title: isArabic ? 'صافي الأرباح التجاريه' : 'Net Commercial Profit',
                      value: currencyFormat.format(state.totalProfit),
                      icon: Icons.attach_money_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    StatsCard(
                      title: isArabic ? 'ديون العملاء المستحقة' : 'Clients Debt',
                      value: currencyFormat.format(state.totalClientsDebt),
                      icon: Icons.account_balance_wallet_rounded,
                      color: Colors.redAccent,
                    ),
                    StatsCard(
                      title: isArabic ? 'قيمة المخزون التجاري' : 'Inventory Value (Cost)',
                      value: currencyFormat.format(state.totalInventoryCostValue),
                      icon: Icons.inventory_2_rounded,
                      color: Colors.teal,
                    ),
                    StatsCard(
                      title: isArabic ? 'نواقص المخزون' : 'Low Stock Items',
                      value: '${state.lowStockCount}',
                      icon: Icons.warning_amber_rounded,
                      color:
                          state.lowStockCount > 0
                              ? AppTheme.dangerColor
                              : AppTheme.successColor,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // ── Monthly Performance Chart & Top Products ────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 850) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildSalesChart(context, state, isArabic),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: _buildTopProducts(context, state, isArabic)),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildSalesChart(context, state, isArabic),
                    const SizedBox(height: 20),
                    _buildTopProducts(context, state, isArabic),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // ── Recent Commercial Sales Invoices Table ─────────────────
            _buildRecentSalesInvoices(context, state, isArabic),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart(BuildContext context, DashboardLoaded state, bool isArabic) {
    final entries =
        state.monthlySalesRevenue.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'المبيعات الشهرية التجارية' : 'Monthly Sales Revenue',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 240,
              child:
                  entries.isEmpty
                      ? Center(
                        child: Text(
                          isArabic ? 'لا توجد بيانات مبيعات في هذه الفترة' : 'No sales data for this period',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                      : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY:
                              entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) *
                              1.2,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final label = entries[group.x.toInt()].key;
                                return BarTooltipItem(
                                  '$label\n\$${rod.toY.toStringAsFixed(2)}',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < entries.length) {
                                    final parts = entries[idx].key.split('-');
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        parts.length > 1 ? '${parts[1]}/${parts[0].substring(2)}' : entries[idx].key,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups:
                              entries.asMap().entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value.value,
                                      color: AppTheme.primaryColor,
                                      width: 18,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6),
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
    );
  }

  Widget _buildTopProducts(BuildContext context, DashboardLoaded state, bool isArabic) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'المنتجات الأعلى قيمة بالمخزون' : 'Top Inventory Products',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.topProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    isArabic ? 'لا توجد منتجات مسجلة حتى الآن' : 'No products found',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.topProducts.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final p = state.topProducts[index];
                  final stockVal = p.stockQuantity * p.price;
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${isArabic ? "المقاس:" : "Size:"} ${p.size.isEmpty ? "-" : p.size} • ${isArabic ? "الكمية:" : "Stock:"} ${p.stockQuantity}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFormat.format(stockVal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSalesInvoices(BuildContext context, DashboardLoaded state, bool isArabic) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFmt = DateFormat('yyyy/MM/dd HH:mm');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'أحدث فواتير المبيعات التجارية' : 'Recent Sales Invoices',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.recentSalesInvoices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    isArabic ? 'لا توجد فواتير مبيعات مسجلة مؤخراً' : 'No recent sales invoices',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              )
            else
              HorizontalScrollableTable(
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 24,
                    columns: [
                      DataColumn(label: Text(isArabic ? 'رقم الفاتورة' : 'Invoice #')),
                      DataColumn(label: Text(isArabic ? 'اسم العميل' : 'Client')),
                      DataColumn(label: Text(isArabic ? 'التاريخ' : 'Date')),
                      DataColumn(label: Text(isArabic ? 'الإجمالي' : 'Total'), numeric: true),
                      DataColumn(label: Text(isArabic ? 'المدفوع' : 'Paid'), numeric: true),
                      DataColumn(label: Text(isArabic ? 'المتبقي' : 'Remaining'), numeric: true),
                      DataColumn(label: Text(isArabic ? 'الحالة' : 'Status')),
                    ],
                    rows: state.recentSalesInvoices.map((inv) {
                      final total = (inv['totalAmount'] as num).toDouble();
                      final paid = (inv['paidAmount'] as num).toDouble();
                      final remaining = (inv['remainingAmount'] as num).toDouble();

                      Color statusColor = Colors.green;
                      String statusText = isArabic ? 'مدفوع بالكامل' : 'Paid';
                      if (remaining > 0 && paid > 0) {
                        statusColor = Colors.orange;
                        statusText = isArabic ? 'مدفوع جزئياً' : 'Partial';
                      } else if (remaining > 0 && paid == 0) {
                        statusColor = Colors.red;
                        statusText = isArabic ? 'غير مدفوع' : 'Unpaid';
                      }

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              inv['invoiceNumber'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataCell(Text(inv['clientName'])),
                          DataCell(Text(dateFmt.format(inv['date']))),
                          DataCell(Text(currencyFormat.format(total))),
                          DataCell(Text(currencyFormat.format(paid))),
                          DataCell(Text(currencyFormat.format(remaining))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
    );
  }
}

class _RangePill extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  const _RangePill({
    required this.label,
    required this.selected,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final unselectedBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : theme.cardColor;
    final unselectedBorder = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : theme.dividerColor;
    final unselectedText = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : AppTheme.textPrimary;
    final unselectedIcon = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : AppTheme.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? primary : unselectedBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? primary : unselectedBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : unselectedIcon,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? Colors.white : unselectedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}