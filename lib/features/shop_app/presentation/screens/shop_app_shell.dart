import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../../../auth/bloc/auth_state.dart';
import 'shop_dashboard_screen.dart';
import 'shop_orders_screen.dart';
import 'shop_products_screen.dart';
import 'shop_transactions_screen.dart';

class ShopAppShell extends StatefulWidget {
  const ShopAppShell({super.key});

  @override
  State<ShopAppShell> createState() => _ShopAppShellState();
}

class _ShopAppShellState extends State<ShopAppShell> {
  int _selectedIndex = 0;

  static const _screens = <_ShopNavItem>[
    _ShopNavItem(
      icon: Icons.dashboard_rounded,
      label: 'Home',
      screen: ShopDashboardScreen(),
    ),
    _ShopNavItem(
      icon: Icons.inventory_2_rounded,
      label: 'Products',
      screen: ShopProductsScreen(),
    ),
    _ShopNavItem(
      icon: Icons.receipt_long_rounded,
      label: 'Orders',
      screen: ShopOrdersScreen(),
    ),
    _ShopNavItem(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Account',
      screen: ShopTransactionsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(user?.shopName ?? 'My Shop'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'logout') {
                    context.read<AuthBloc>().add(AuthLogoutRequested());
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'User',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(user?.email ?? '',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: _screens[_selectedIndex].screen,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppTheme.primaryColor,
            items: _screens
                .map((s) =>
                    BottomNavigationBarItem(icon: Icon(s.icon), label: s.label))
                .toList(),
          ),
        );
      },
    );
  }
}

class _ShopNavItem {
  final IconData icon;
  final String label;
  final Widget screen;

  const _ShopNavItem({
    required this.icon,
    required this.label,
    required this.screen,
  });
}
