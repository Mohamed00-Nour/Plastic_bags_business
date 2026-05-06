import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/bloc/locale_cubit.dart';
import '../../../../core/bloc/theme_cubit.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../../../auth/bloc/auth_state.dart';
import 'shop_dashboard_screen.dart';
import 'shop_orders_screen.dart';
import 'shop_products_screen.dart';
import 'shop_purchases_screen.dart';
import 'shop_transactions_screen.dart';

class ShopAppShell extends StatefulWidget {
  const ShopAppShell({super.key});

  @override
  State<ShopAppShell> createState() => _ShopAppShellState();
}

class _ShopAppShellState extends State<ShopAppShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _setupFcm();
  }

  Future<void> _setupFcm() async {
    // FCM topic subscription only works on Android and iOS
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return;
    }

    final messaging = FirebaseMessaging.instance;

    // Request permission (required on iOS)
    await messaging.requestPermission();

    // Subscribe to the topic that the admin targets
    await messaging.subscribeToTopic('announcements');

    // Show OS-level notification when a foreground message arrives
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        NotificationService.show(
          title: notification.title ?? '',
          body: notification.body ?? '',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screens = <_ShopNavItem>[
      _ShopNavItem(
        icon: Icons.dashboard_rounded,
        label: l10n.shopDashboard,
        screen: const ShopDashboardScreen(),
      ),
      _ShopNavItem(
        icon: Icons.inventory_2_rounded,
        label: l10n.products,
        screen: const ShopProductsScreen(),
      ),
      _ShopNavItem(
        icon: Icons.receipt_long_rounded,
        label: l10n.orders,
        screen: const ShopOrdersScreen(),
      ),
      _ShopNavItem(
        icon: Icons.shopping_bag_rounded,
        label: l10n.myPurchases,
        screen: const ShopPurchasesScreen(),
      ),
      _ShopNavItem(
        icon: Icons.account_balance_wallet_rounded,
        label: l10n.transactions,
        screen: const ShopTransactionsScreen(),
      ),
    ];

    if (_selectedIndex >= screens.length) _selectedIndex = 0;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(user?.shopName ?? l10n.shopDashboard),
            actions: [
              // Theme toggle
              IconButton(
                onPressed: () => context.read<ThemeCubit>().toggleTheme(),
                icon: Icon(
                  context.watch<ThemeCubit>().isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  size: 22,
                ),
                tooltip: l10n.toggleTheme,
              ),
              // Locale toggle
              IconButton(
                onPressed: () => context.read<LocaleCubit>().toggleLocale(),
                icon: const Icon(Icons.language_rounded, size: 22),
                tooltip: l10n.toggleLanguage,
              ),
              // User menu
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
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.logout),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: screens[_selectedIndex].screen,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: screens
                .map((s) => NavigationDestination(
                      icon: Icon(s.icon),
                      label: s.label,
                    ))
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
