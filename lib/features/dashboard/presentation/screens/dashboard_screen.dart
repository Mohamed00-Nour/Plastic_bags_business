import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/stats_card.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/order_model.dart';
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
                      l10n.overview,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    if (state.selectedRange == DashboardDateRange.custom &&
                        state.customStart != null &&
                        state.customEnd != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${DateFormat('MMM d, y').format(state.customStart!)} – ${DateFormat('MMM d, y').format(state.customEnd!)}',
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
            // ── Range filter pills ─────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children: [
                  ...DashboardDateRange.values
                      .where((r) => r != DashboardDateRange.custom)
                      .map((range) {
                    final isSelected = state.selectedRange == range;
                    return _RangePill(
                      label: _localizedRangeLabel(l10n, range),
                      selected: isSelected,
                      onTap: () => context
                          .read<DashboardBloc>()
                          .add(DashboardFilterChanged(range)),
                    );
                  }),
                  _RangePill(
                    label: l10n.customRange,
                    selected: state.selectedRange == DashboardDateRange.custom,
                    icon: Icons.date_range_rounded,
                    onTap: () => _pickCustomRange(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount =
                    constraints.maxWidth > 1000
                        ? 4
                        : constraints.maxWidth > 600
                        ? 2
                        : 1;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.6,
                  children: [
                    StatsCard(
                      title: l10n.totalSales,
                      value: currencyFormat.format(state.totalSales),
                      icon: Icons.trending_up_rounded,
                      color: AppTheme.successColor,
                    ),
                    StatsCard(
                      title: l10n.totalProfit,
                      value: currencyFormat.format(state.totalProfit),
                      icon: Icons.attach_money_rounded,
                      color: AppTheme.successColor,
                    ),
                    StatsCard(
                      title: l10n.projectedSales,
                      value: currencyFormat.format(state.expectedSales),
                      icon: Icons.inventory_2_rounded,
                      color: AppTheme.infoColor,
                    ),
                    StatsCard(
                      title: l10n.pendingOrders,
                      value: '${state.pendingOrders}',
                      icon: Icons.pending_actions_rounded,
                      color: AppTheme.warningColor,
                    ),
                    StatsCard(
                      title: l10n.activeShops,
                      value: '${state.activeShops}',
                      icon: Icons.store_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    StatsCard(
                      title: l10n.lowStockItems,
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
            // Charts and tables row
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildSalesChart(context, state),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: _buildTopProducts(context, state)),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildSalesChart(context, state),
                    const SizedBox(height: 20),
                    _buildTopProducts(context, state),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Recent Orders
            _buildRecentOrders(context, state),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart(BuildContext context, DashboardLoaded state) {
    final l10n = AppLocalizations.of(context)!;
    final entries =
        state.monthlySales.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.monthlySales,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child:
                  entries.isEmpty
                      ? Center(
                        child: Text(
                          l10n.noSalesData,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                      : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY:
                              entries.isEmpty
                                  ? 100
                                  : entries
                                          .map((e) => e.value)
                                          .reduce((a, b) => a > b ? a : b) *
                                      1.2,
                          barTouchData: BarTouchData(enabled: true),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 && index < entries.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        entries[index].key.substring(5),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    NumberFormat.compact().format(value),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: true),
                          barGroups:
                              entries.asMap().entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value.value,
                                      color: AppTheme.primaryColor,
                                      width: 20,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
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

  Widget _buildTopProducts(BuildContext context, DashboardLoaded state) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.topProducts,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (state.topProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    l10n.noProductsYet,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              )
            else
              ...state.topProducts.map(
                (product) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    product.name,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    product.size,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders(BuildContext context, DashboardLoaded state) {
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recentOrders,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (state.recentOrders.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    l10n.noOrdersYet,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(l10n.orderId)),
                    DataColumn(label: Text(l10n.shop)),
                    DataColumn(label: Text(l10n.total)),
                    DataColumn(label: Text(l10n.status)),
                    DataColumn(label: Text(l10n.date)),
                  ],
                  rows:
                      state.recentOrders.map((order) {
                        return DataRow(
                          cells: [
                            DataCell(Text('#${order.id.substring(0, 8)}')),
                            DataCell(Text(order.shopName)),
                            DataCell(
                              Text('\$${order.totalPrice.toStringAsFixed(2)}'),
                            ),
                            DataCell(_buildStatusBadge(context, order.status)),
                            DataCell(Text(dateFormat.format(order.createdAt))),
                          ],
                        );
                      }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, OrderStatus status) {
    Color color;
    switch (status) {
      case OrderStatus.pending:
        color = AppTheme.warningColor;
        break;
      case OrderStatus.approved:
        color = AppTheme.successColor;
        break;
      case OrderStatus.rejected:
        color = AppTheme.dangerColor;
        break;
      case OrderStatus.delivered:
        color = AppTheme.infoColor;
        break;
    }
    return StatusBadge(
      label: _localizedOrderStatus(AppLocalizations.of(context)!, status),
      color: color,
    );
  }

  String _localizedRangeLabel(AppLocalizations l10n, DashboardDateRange range) {
    switch (range) {
      case DashboardDateRange.today:
        return l10n.rangeToday;
      case DashboardDateRange.week:
        return l10n.rangeThisWeek;
      case DashboardDateRange.month:
        return l10n.rangeThisMonth;
      case DashboardDateRange.year:
        return l10n.rangeThisYear;
      case DashboardDateRange.all:
        return l10n.rangeAllTime;
      case DashboardDateRange.custom:
        return l10n.customRange;
    }
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
}

class _RangePill extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  const _RangePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}