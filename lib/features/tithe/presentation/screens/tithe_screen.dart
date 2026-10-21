import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../data/models/tithe_payout_model.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_state.dart';
import '../../bloc/tithe_bloc.dart';
import '../../bloc/tithe_event.dart';
import '../../bloc/tithe_state.dart';

class TitheScreen extends StatefulWidget {
  const TitheScreen({super.key});

  @override
  State<TitheScreen> createState() => _TitheScreenState();
}

class _TitheScreenState extends State<TitheScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  final DateFormat _monthFormatAr = DateFormat('MMMM yyyy', 'ar');
  final DateFormat _monthFormatEn = DateFormat('MMMM yyyy', 'en');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<TitheBloc>().add(const TitheLoadRequested());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return BlocConsumer<TitheBloc, TitheState>(
      listener: (context, state) {
        if (state is TitheError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is TitheLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is! TitheLoaded) {
          return Center(
            child: ElevatedButton.icon(
              onPressed: () =>
                  context.read<TitheBloc>().add(const TitheLoadRequested()),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Header Toolbar ──
                _buildHeaderToolbar(context, state, isArabic, isDark),
                const SizedBox(height: 16),

                // ── KPI Summary Cards ──
                _buildKPICards(context, state, isArabic, isDark),
                const SizedBox(height: 16),

                // ── Tabs Navigation ──
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppTheme.borderDark : Colors.grey.shade300,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor:
                        isDark ? Colors.white60 : Colors.black87,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    tabs: [
                      Tab(
                        iconMargin: EdgeInsets.zero,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(isArabic ? 'سجلات الصرف من العشور' : 'Payout Records'),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${state.filteredPayouts.length}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_view_month_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(isArabic ? 'إجمالي العشور شهرياً (10%)' : 'Monthly 10% Summary'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Tab Views ──
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Payout Records
                      _buildPayoutsTab(context, state, isArabic, isDark),
                      // Tab 2: Monthly Summary
                      _buildMonthlySummaryTab(context, state, isArabic, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Header Toolbar
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHeaderToolbar(
    BuildContext context,
    TitheLoaded state,
    bool isArabic,
    bool isDark,
  ) {
    return ResponsiveLayout(
      mobile: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  color: AppTheme.primaryLight,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'خانة العشور (10% من الأرباح)' : 'Tithe (10% Profit Share)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isArabic
                          ? 'إدارة ومتابعة عشور الأرباح وسجلات الصرف'
                          : 'Manage profit tithe and disbursement records',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showPayoutDialog(context, null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: Text(
                    isArabic ? 'صرف من العشور' : 'New Disbursement',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () =>
                    context.read<TitheBloc>().add(const TitheLoadRequested()),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: isArabic ? 'تحديث' : 'Refresh',
              ),
            ],
          ),
        ],
      ),
      desktop: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: AppTheme.primaryLight,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'خانة العشور (10% من الأرباح)' : 'Tithe (10% Profit Share)',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                isArabic
                    ? 'إدارة ومتابعة عشور الأرباح وسجلات الصرف المستحقة'
                    : 'Track profit tithe accruals, monthly totals, and payout records',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showPayoutDialog(context, null),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
              shadowColor: AppTheme.successColor.withValues(alpha: 0.4),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
            label: Text(
              isArabic ? 'تسجيل صرف من العشور' : 'New Disbursement',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () =>
                context.read<TitheBloc>().add(const TitheLoadRequested()),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(isArabic ? 'تحديث البيانات' : 'Refresh'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // KPI Summary Cards
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildKPICards(
    BuildContext context,
    TitheLoaded state,
    bool isArabic,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        final cardSpacing = isCompact ? 10.0 : 14.0;

        final availableBalanceCard = _buildBalanceCard(
          title: isArabic ? 'الرصيد المتبقي للعشور' : 'Available Tithe Balance',
          amount: state.currentBalance,
          subtitle: isArabic
              ? 'العشور المستحقة - إجمالي المصروف'
              : 'Total Accrued - Total Disbursed',
          icon: Icons.account_balance_wallet_rounded,
          isHighlight: true,
          isArabic: isArabic,
          isDark: isDark,
        );

        final totalAccruedCard = _buildMetricCard(
          title: isArabic ? 'إجمالي العشور (10%)' : 'Total 10% Tithe Accrued',
          amount: state.totalAllTimeTithe,
          subtitle: isArabic
              ? 'من إجمالي صافي الأرباح: ${_currencyFormat.format(state.totalAllTimeProfit)}'
              : 'From net profit: ${_currencyFormat.format(state.totalAllTimeProfit)}',
          icon: Icons.savings_rounded,
          color: AppTheme.primaryColor,
          isArabic: isArabic,
          isDark: isDark,
        );

        final totalDisbursedCard = _buildMetricCard(
          title: isArabic ? 'إجمالي المصروف من العشور' : 'Total Tithe Disbursed',
          amount: state.totalAllTimeDisbursed,
          subtitle: isArabic
              ? '${state.allPayouts.length} حركة صرف مسجلة'
              : '${state.allPayouts.length} payout records',
          icon: Icons.payments_rounded,
          color: AppTheme.dangerColor,
          isArabic: isArabic,
          isDark: isDark,
        );

        final currentMonthCard = _buildMetricCard(
          title: isArabic ? 'عشور الشهر الحالي' : 'Current Month 10% Tithe',
          amount: state.currentMonthTithe,
          subtitle: isArabic
              ? 'مصروف الشهر: ${_currencyFormat.format(state.currentMonthDisbursed)} (المتبقي: ${_currencyFormat.format(state.currentMonthNetRemaining)})'
              : 'Month Payout: ${_currencyFormat.format(state.currentMonthDisbursed)}',
          icon: Icons.calendar_month_rounded,
          color: AppTheme.warningColor,
          isArabic: isArabic,
          isDark: isDark,
        );

        if (isCompact) {
          return Column(
            children: [
              availableBalanceCard,
              SizedBox(height: cardSpacing),
              Row(
                children: [
                  Expanded(child: totalAccruedCard),
                  SizedBox(width: cardSpacing),
                  Expanded(child: totalDisbursedCard),
                ],
              ),
              SizedBox(height: cardSpacing),
              currentMonthCard,
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: availableBalanceCard),
            SizedBox(width: cardSpacing),
            Expanded(flex: 3, child: totalAccruedCard),
            SizedBox(width: cardSpacing),
            Expanded(flex: 3, child: totalDisbursedCard),
            SizedBox(width: cardSpacing),
            Expanded(flex: 3, child: currentMonthCard),
          ],
        );
      },
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required double amount,
    required String subtitle,
    required IconData icon,
    required bool isHighlight,
    required bool isArabic,
    required bool isDark,
  }) {
    final isPositive = amount >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [
                  const Color(0xFF0D9488), // Teal 600
                  const Color(0xFF047857), // Emerald 700
                ]
              : [
                  const Color(0xFFE11D48), // Rose 600
                  const Color(0xFFBE123C), // Rose 700
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isPositive ? const Color(0xFF059669) : const Color(0xFFE11D48))
                .withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_currencyFormat.format(amount)} ${isArabic ? 'ج.م' : 'EGP'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isArabic,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_currencyFormat.format(amount)} ${isArabic ? 'ج.م' : 'EGP'}',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tab 1: Payout Records
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPayoutsTab(
    BuildContext context,
    TitheLoaded state,
    bool isArabic,
    bool isDark,
  ) {
    return Column(
      children: [
        // ── Filter Bar: Search + Date Range Presets ──
        _buildFilterBar(context, state, isArabic, isDark),
        const SizedBox(height: 14),

        // ── Records Table / List ──
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : Colors.grey.shade200,
              ),
            ),
            child: state.filteredPayouts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: isDark ? Colors.white38 : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isArabic
                                ? 'لا توجد سجلات صرف مطابقة'
                                : 'No payout records found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isArabic
                                ? 'يمكنك تسجيل صرف جديد أو تغيير فلتر التاريخ'
                                : 'You can create a new disbursement or adjust the date filter',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white38 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 24,
                          horizontalMargin: 20,
                          headingRowColor: WidgetStateProperty.all(
                            isDark
                                ? AppTheme.sidebarItemColor
                                : Colors.grey.shade100,
                          ),
                          columns: [
                            DataColumn(
                              label: Text(
                                '#',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                isArabic ? 'التاريخ' : 'Date',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                isArabic ? 'الجهة المستفيدة / المستلم' : 'Recipient',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                isArabic ? 'المبلغ المصروف' : 'Amount',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                isArabic ? 'البيان / تفاصيل الصرف' : 'Notes / Description',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                isArabic ? 'سُجل بواسطة' : 'Created By',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                isArabic ? 'الإجراءات' : 'Actions',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: state.filteredPayouts.asMap().entries.map((entry) {
                            final index = entry.key + 1;
                            final payout = entry.value;
                            return DataRow(
                              cells: [
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '#$index',
                                      style: const TextStyle(
                                        color: AppTheme.primaryLight,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _dateFormat.format(payout.date),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: AppTheme.primaryColor
                                            .withValues(alpha: 0.2),
                                        child: Text(
                                          payout.recipient.isNotEmpty
                                              ? payout.recipient
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.primaryLight,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        payout.recipient,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.dangerColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_currencyFormat.format(payout.amount)} ${isArabic ? 'ج.م' : 'EGP'}',
                                      style: const TextStyle(
                                        color: AppTheme.dangerColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 220,
                                    child: Text(
                                      payout.notes.isNotEmpty ? payout.notes : '-',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    payout.createdByName.isNotEmpty
                                        ? payout.createdByName
                                        : '-',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: AppTheme.accentColor,
                                        ),
                                        tooltip: isArabic ? 'تعديل' : 'Edit',
                                        onPressed: () =>
                                            _showPayoutDialog(context, payout),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: AppTheme.dangerColor,
                                        ),
                                        tooltip: isArabic ? 'حذف' : 'Delete',
                                        onPressed: () => _showDeleteConfirmation(
                                          context,
                                          payout,
                                          isArabic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Filter Bar
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildFilterBar(
    BuildContext context,
    TitheLoaded state,
    bool isArabic,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : Colors.grey.shade200,
        ),
      ),
      child: ResponsiveLayout(
        mobile: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchField(context, isArabic, isDark),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildDateChips(context, state, isArabic),
              ),
            ),
            const SizedBox(height: 8),
            _buildTotalBadge(state, isArabic),
          ],
        ),
        desktop: Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildSearchField(context, isArabic, isDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _buildDateChips(context, state, isArabic),
                ),
              ),
            ),
            const SizedBox(width: 14),
            _buildTotalBadge(state, isArabic),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, bool isArabic, bool isDark) {
    return TextField(
      controller: _searchController,
      onChanged: (val) =>
          context.read<TitheBloc>().add(TitheSearchChanged(query: val)),
      decoration: InputDecoration(
        hintText: isArabic
            ? 'بحث بالجهة أو المستفيد أو البيان...'
            : 'Search recipient or notes...',
        hintStyle: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white38 : Colors.grey.shade500,
        ),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  context
                      .read<TitheBloc>()
                      .add(const TitheSearchChanged(query: ''));
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? AppTheme.sidebarItemColor : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  List<Widget> _buildDateChips(
    BuildContext context,
    TitheLoaded state,
    bool isArabic,
  ) {
    final filters = [
      {'range': TitheDateRange.all, 'label': isArabic ? 'الكل' : 'All'},
      {'range': TitheDateRange.today, 'label': isArabic ? 'اليوم' : 'Today'},
      {
        'range': TitheDateRange.thisWeek,
        'label': isArabic ? 'هذا الأسبوع' : 'This Week',
      },
      {
        'range': TitheDateRange.thisMonth,
        'label': isArabic ? 'هذا الشهر' : 'This Month',
      },
      {
        'range': TitheDateRange.lastMonth,
        'label': isArabic ? 'الشهر الماضي' : 'Last Month',
      },
      {
        'range': TitheDateRange.thisYear,
        'label': isArabic ? 'هذا العام' : 'This Year',
      },
      {
        'range': TitheDateRange.custom,
        'label': isArabic ? 'فترة مخصصة' : 'Custom Range',
      },
    ];

    return filters.map((f) {
      final range = f['range'] as TitheDateRange;
      final label = f['label'] as String;
      final isSelected = state.selectedRange == range;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (selected) async {
            if (!selected) return;
            if (range == TitheDateRange.custom) {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: state.customStart != null &&
                        state.customEnd != null
                    ? DateTimeRange(
                        start: state.customStart!,
                        end: state.customEnd!,
                      )
                    : null,
              );
              if (picked != null) {
                if (!context.mounted) return;
                context.read<TitheBloc>().add(
                      TitheDateRangeChanged(
                        range: TitheDateRange.custom,
                        customStart: picked.start,
                        customEnd: picked.end,
                      ),
                    );
              }
            } else {
              context.read<TitheBloc>().add(
                    TitheDateRangeChanged(range: range),
                  );
            }
          },
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : null,
          ),
          selectedColor: AppTheme.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTotalBadge(TitheLoaded state, bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.dangerColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.dangerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_rounded,
            size: 16,
            color: AppTheme.dangerColor,
          ),
          const SizedBox(width: 6),
          Text(
            isArabic
                ? 'إجمالي الصرف المعروض: ${_currencyFormat.format(state.filteredPayoutsTotal)} ج.م'
                : 'Filtered Total: ${_currencyFormat.format(state.filteredPayoutsTotal)} EGP',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.dangerColor,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tab 2: Monthly 10% Summary
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMonthlySummaryTab(
    BuildContext context,
    TitheLoaded state,
    bool isArabic,
    bool isDark,
  ) {
    if (state.monthlyBreakdown.isEmpty) {
      return Center(
        child: Text(
          isArabic ? 'لا توجد بيانات شهرية متاحة' : 'No monthly data available',
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : Colors.grey.shade200,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 28,
              horizontalMargin: 22,
              headingRowColor: WidgetStateProperty.all(
                isDark ? AppTheme.sidebarItemColor : Colors.grey.shade100,
              ),
              columns: [
                DataColumn(
                  label: Text(
                    isArabic ? 'الشهر / السنة' : 'Month / Year',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    isArabic ? 'إجمالي المبيعات' : 'Sales Revenue',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    isArabic ? 'صافي أرباح الشهر' : 'Monthly Net Profit',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    isArabic ? 'العشور المستحقة (10%)' : '10% Tithe Accrued',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    isArabic ? 'المصروف من العشور' : 'Disbursed',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    isArabic ? 'المتبقي الصافي للشهر' : 'Month Net Remaining',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: state.monthlyBreakdown.map((m) {
                final monthTitle = isArabic
                    ? _monthFormatAr.format(m.monthDate)
                    : _monthFormatEn.format(m.monthDate);
                final isPositiveRemaining = m.netRemaining >= 0;

                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: AppTheme.primaryLight,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            monthTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        '${_currencyFormat.format(m.salesRevenue)} ${isArabic ? 'ج.م' : 'EGP'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${_currencyFormat.format(m.netProfit)} ${isArabic ? 'ج.م' : 'EGP'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: m.netProfit >= 0
                              ? AppTheme.successColor
                              : AppTheme.dangerColor,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_currencyFormat.format(m.titheAccrued)} ${isArabic ? 'ج.م' : 'EGP'}',
                          style: const TextStyle(
                            color: AppTheme.primaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${_currencyFormat.format(m.titheDisbursed)} ${isArabic ? 'ج.م' : 'EGP'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: m.titheDisbursed > 0
                              ? AppTheme.dangerColor
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (isPositiveRemaining
                                  ? AppTheme.successColor
                                  : AppTheme.dangerColor)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_currencyFormat.format(m.netRemaining)} ${isArabic ? 'ج.م' : 'EGP'}',
                          style: TextStyle(
                            color: isPositiveRemaining
                                ? AppTheme.successColor
                                : AppTheme.dangerColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Payout Dialog (Create / Edit)
  // ──────────────────────────────────────────────────────────────────────────
  void _showPayoutDialog(BuildContext context, TithePayoutModel? existing) {
    final isEdit = existing != null;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(
      text: isEdit ? existing.amount.toStringAsFixed(2) : '',
    );
    final recipientController = TextEditingController(
      text: isEdit ? existing.recipient : '',
    );
    final notesController = TextEditingController(
      text: isEdit ? existing.notes : '',
    );
    DateTime selectedDate = isEdit ? existing.date : DateTime.now();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor:
                  isDark ? AppTheme.surfaceDark : Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: AppTheme.successColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit
                        ? (isArabic ? 'تعديل حركة صرف' : 'Edit Disbursement')
                        : (isArabic
                            ? 'تسجيل صرف جديد من العشور'
                            : 'New Tithe Disbursement'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amount Field
                        Text(
                          isArabic ? 'المبلغ المصروف *' : 'Disbursement Amount *',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixIcon: const Icon(
                              Icons.attach_money_rounded,
                              size: 20,
                            ),
                            suffixText: isArabic ? 'ج.م' : 'EGP',
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.sidebarItemColor
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return isArabic
                                  ? 'يرجى إدخال المبلغ'
                                  : 'Please enter an amount';
                            }
                            final num = double.tryParse(val.trim());
                            if (num == null || num <= 0) {
                              return isArabic
                                  ? 'يرجى إدخال مبلغ صحيح أكبر من الصفر'
                                  : 'Please enter a valid amount greater than 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Recipient Field
                        Text(
                          isArabic
                              ? 'الجهة المستفيدة / المستلم *'
                              : 'Beneficiary / Recipient *',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: recipientController,
                          decoration: InputDecoration(
                            hintText: isArabic
                                ? 'اسم المستفيد أو الجهة...'
                                : 'Recipient name or organization...',
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.sidebarItemColor
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return isArabic
                                  ? 'يرجى إدخال اسم المستفيد'
                                  : 'Please enter recipient name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Date Picker Field
                        Text(
                          isArabic ? 'تاريخ الصرف *' : 'Disbursement Date *',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.sidebarItemColor
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.borderDark
                                    : Colors.grey.shade400,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: AppTheme.primaryLight,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _dateFormat.format(selectedDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.arrow_drop_down_rounded,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Notes Field
                        Text(
                          isArabic
                              ? 'البيان / تفاصيل الصرف'
                              : 'Notes / Statement',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: isArabic
                                ? 'أي ملاحظات أو تفاصيل إضافية...'
                                : 'Any additional details or purpose of payout...',
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.sidebarItemColor
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;

                    final amount = double.parse(amountController.text.trim());
                    final recipient = recipientController.text.trim();
                    final notes = notesController.text.trim();

                    final authState = context.read<AuthBloc>().state;
                    final currentUser = authState is AuthAuthenticated
                        ? authState.user
                        : null;

                    if (isEdit) {
                      final updated = existing.copyWith(
                        amount: amount,
                        recipient: recipient,
                        date: selectedDate,
                        notes: notes,
                        updatedAt: DateTime.now(),
                      );
                      context.read<TitheBloc>().add(
                            TithePayoutUpdated(payout: updated),
                          );
                    } else {
                      final newPayout = TithePayoutModel(
                        id: '',
                        amount: amount,
                        date: selectedDate,
                        recipient: recipient,
                        notes: notes,
                        createdByName: currentUser?.name ?? 'Admin',
                        createdByUid: currentUser?.id ?? '',
                        createdAt: DateTime.now(),
                      );
                      context.read<TitheBloc>().add(
                            TithePayoutCreated(payout: newPayout),
                          );
                    }

                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit
                              ? (isArabic
                                  ? 'تم تعديل حركة الصرف بنجاح'
                                  : 'Disbursement updated successfully')
                              : (isArabic
                                  ? 'تم تسجيل صرف العشور بنجاح'
                                  : 'Tithe disbursement recorded successfully'),
                        ),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    isEdit
                        ? (isArabic ? 'حفظ التعديلات' : 'Save Changes')
                        : (isArabic ? 'تأكيد الصرف' : 'Confirm Payout'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Delete Confirmation Dialog
  // ──────────────────────────────────────────────────────────────────────────
  void _showDeleteConfirmation(
    BuildContext context,
    TithePayoutModel payout,
    bool isArabic,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.dangerColor,
                size: 26,
              ),
              const SizedBox(width: 10),
              Text(
                isArabic ? 'حذف حركة الصرف' : 'Delete Disbursement',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            isArabic
                ? 'هل أنت متأكد من حذف حركة الصرف بقيمة (${_currencyFormat.format(payout.amount)} ج.م) للجهة "${payout.recipient}"؟'
                : 'Are you sure you want to delete payout of (${_currencyFormat.format(payout.amount)} EGP) for "${payout.recipient}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<TitheBloc>().add(
                      TithePayoutDeleted(payoutId: payout.id),
                    );
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isArabic
                          ? 'تم حذف حركة الصرف بنجاح'
                          : 'Disbursement deleted successfully',
                    ),
                    backgroundColor: AppTheme.dangerColor,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor,
                foregroundColor: Colors.white,
              ),
              child: Text(isArabic ? 'نعم، حذف' : 'Yes, Delete'),
            ),
          ],
        );
      },
    );
  }
}
