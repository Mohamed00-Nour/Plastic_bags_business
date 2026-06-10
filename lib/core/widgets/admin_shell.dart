import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/bloc/locale_cubit.dart';
import '../../core/bloc/theme_cubit.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/user_model.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_event.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/products/presentation/screens/products_screen_new.dart';
import '../../features/shops/presentation/screens/shops_screen.dart';
import '../../features/suppliers/presentation/screens/suppliers_screen_new.dart';
import '../../features/orders/presentation/screens/orders_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../features/reports/presentation/screens/reports_screen_new.dart';
import '../../features/users/presentation/screens/users_screen.dart';
import '../../features/stock_logs/presentation/screens/stock_logs_screen.dart';
import '../../features/manufacturing/presentation/screens/manufacturing_shell.dart';
import '../../features/announcements/presentation/screens/announcements_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  List<_NavItem> _getNavItems(BuildContext context, UserRole role) {
    final l10n = AppLocalizations.of(context)!;
    return [
      _NavItem(
        icon: Icons.dashboard_rounded,
        label: l10n.dashboard,
        screen: const DashboardScreen(),
      ),
      _NavItem(
        icon: Icons.inventory_2_rounded,
        label: l10n.products,
        screen: const ProductsScreen(),
      ),
      _NavItem(
        icon: Icons.store_rounded,
        label: l10n.shops,
        screen: const ShopsScreen(),
      ),
      _NavItem(
        icon: Icons.local_shipping_rounded,
        label: l10n.suppliers,
        screen: const SuppliersScreen(),
      ),
      _NavItem(
        icon: Icons.receipt_long_rounded,
        label: l10n.orders,
        screen: const OrdersScreen(),
      ),
      _NavItem(
        icon: Icons.account_balance_wallet_rounded,
        label: l10n.transactions,
        screen: const TransactionsScreen(),
      ),
      _NavItem(
        icon: Icons.history_rounded,
        label: l10n.stockLog,
        screen: const StockLogsScreen(),
      ),
      _NavItem(
        icon: Icons.bar_chart_rounded,
        label: l10n.reports,
        screen: const ReportsScreen(),
      ),
      if (role.canManageUsers)
        _NavItem(
          icon: Icons.people_rounded,
          label: l10n.users,
          screen: const UsersScreen(),
        ),
      _NavItem(
        icon: Icons.precision_manufacturing_rounded,
        label: l10n.manufacturing,
        screen: const ManufacturingShell(),
      ),
      if (role.canManageUsers)
        _NavItem(
          icon: Icons.campaign_rounded,
          label: l10n.announcements,
          screen: const AnnouncementsScreen(),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final role = user?.role ?? UserRole.viewer;
        final navItems = _getNavItems(context, role);

        if (_selectedIndex >= navItems.length) {
          _selectedIndex = 0;
        }

        return ResponsiveLayout(
          mobile: _MobileLayout(
            navItems: navItems,
            selectedIndex: _selectedIndex,
            onIndexChanged: (i) => setState(() => _selectedIndex = i),
            user: user,
            onLogout: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
          ),
          desktop: _DesktopLayout(
            navItems: navItems,
            selectedIndex: _selectedIndex,
            onIndexChanged: (i) => setState(() => _selectedIndex = i),
            user: user,
            onLogout: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
          ),
        );
      },
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final List<_NavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final UserModel? user;
  final VoidCallback onLogout;

  const _DesktopLayout({
    required this.navItems,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ── Floating Sidebar ──────────────────────────────────────
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: AppTheme.sidebarColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    // Logo
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 32, horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.35),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: AppTheme.primaryLight,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            AppLocalizations.of(context)!.appTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(color: Colors.white10, height: 1),
                    ),
                    const SizedBox(height: 12),
                    // Nav items
                    Expanded(
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: navItems.length,
                        itemBuilder: (context, index) {
                          final item = navItems[index];
                          final isSelected = index == selectedIndex;
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 3),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.sidebarItemColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                          .withValues(alpha: 0.5)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => onIndexChanged(index),
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  hoverColor: Colors.white10,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.icon,
                                          color: isSelected
                                              ? AppTheme.primaryLight
                                              : Colors.white54,
                                          size: 21,
                                        ),
                                        const SizedBox(width: 11),
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white54,
                                            fontSize: 14,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // User footer
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.4),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.primaryColor,
                                  child: Text(
                                    (user?.name ?? 'U')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.name ?? 'User',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      user?.role.name.toUpperCase() ??
                                          '',
                                      style: const TextStyle(
                                        color: AppTheme.primaryLight,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout_rounded,
                                    color: Colors.white38, size: 20),
                                onPressed: onLogout,
                                tooltip: AppLocalizations.of(context)!.logout,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // ── Main Content ──────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    children: [
                      // Top bar
                      Container(
                        height: 68,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 28),
                        child: Row(
                          children: [
                            Text(
                              navItems[selectedIndex].label,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {},
                              icon: const Badge(
                                smallSize: 8,
                                child: Icon(
                                    Icons.notifications_outlined,
                                    size: 24),
                              ),
                              tooltip: AppLocalizations.of(context)!.notifications,
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () =>
                                  context.read<ThemeCubit>().toggleTheme(),
                              icon: Icon(
                                context.watch<ThemeCubit>().isDark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                                size: 24,
                              ),
                              tooltip: AppLocalizations.of(context)!.toggleTheme,
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => context
                                  .read<LocaleCubit>()
                                  .toggleLocale(),
                              icon: const Icon(Icons.language_rounded,
                                  size: 24),
                              tooltip: AppLocalizations.of(context)!.toggleLanguage,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(child: navItems[selectedIndex].screen),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final List<_NavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final UserModel? user;
  final VoidCallback onLogout;

  const _MobileLayout({
    required this.navItems,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    // Show max 5 items in bottom nav; rest in drawer
    final bottomNavItems = navItems.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(navItems[selectedIndex].label),
        actions: [
          IconButton(
            onPressed: () => context.read<ThemeCubit>().toggleTheme(),
            icon: Icon(
              context.watch<ThemeCubit>().isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            tooltip: AppLocalizations.of(context)!.toggleTheme,
          ),
          IconButton(
            onPressed: () {
              context.read<LocaleCubit>().toggleLocale();
            },
            icon: const Icon(Icons.language_rounded),
            tooltip: AppLocalizations.of(context)!.toggleLanguage,
          ),
          IconButton(
            onPressed: () {},
            icon: const Badge(
              smallSize: 8,
              child: Icon(Icons.notifications_outlined),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') onLogout();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? 'User',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(user?.role.label ?? '',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 20),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.logout),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: navItems.length > 5
          ? Drawer(
              child: ListView(
                children: [
                  UserAccountsDrawerHeader(
                    accountName: Text(user?.name ?? 'User'),
                    accountEmail: Text(user?.email ?? ''),
                    currentAccountPicture: CircleAvatar(
                      child: Text(
                        (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  ...navItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return ListTile(
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      selected: index == selectedIndex,
                      onTap: () {
                        onIndexChanged(index);
                        Navigator.pop(context);
                      },
                    );
                  }),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: Text(AppLocalizations.of(context)!.logout),
                    onTap: onLogout,
                  ),
                ],
              ),
            )
          : null,
      body: navItems[selectedIndex].screen,
      bottomNavigationBar: Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final navBg = isDark
              ? const Color(0xFF0F172A) // deep navy — same as sidebar
              : colorScheme.surfaceContainer;
          final activeColor = colorScheme.primary;
          final inactiveColor = colorScheme.onSurfaceVariant;
          return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: navBg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: isDark ? 0.30 : 0.20),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.18),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: List.generate(bottomNavItems.length, (index) {
              final item = bottomNavItems[index];
              final isSelected =
                  index == (selectedIndex < bottomNavItems.length ? selectedIndex : 0);
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onIndexChanged(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          color: isSelected ? activeColor : inactiveColor,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isSelected ? activeColor : inactiveColor,
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      );
        },
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Widget screen;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.screen,
  });
}
