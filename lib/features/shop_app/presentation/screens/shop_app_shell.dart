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
      // Pick the locale-appropriate title/body from data payload if available
      final data = message.data;
      final isArabic =
          mounted
              ? context.read<LocaleCubit>().state.languageCode == 'ar'
              : false;

      final titleEn = data['titleEn'] ?? message.notification?.title ?? '';
      final titleAr = data['titleAr'] ?? titleEn;
      final bodyEn = data['bodyEn'] ?? message.notification?.body ?? '';
      final bodyAr = data['bodyAr'] ?? bodyEn;

      NotificationService.show(
        title: isArabic ? titleAr : titleEn,
        body: isArabic ? bodyAr : bodyEn,
      );
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final useRail = constraints.maxWidth >= 900;
            final isCompact = constraints.maxWidth < 480;

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  user?.shopName ?? l10n.shopDashboard,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  if (!isCompact) ...[
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
                    IconButton(
                      onPressed:
                          () => context.read<LocaleCubit>().toggleLocale(),
                      icon: const Icon(Icons.language_rounded, size: 22),
                      tooltip: l10n.toggleLanguage,
                    ),
                  ],
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'theme') {
                        context.read<ThemeCubit>().toggleTheme();
                      } else if (value == 'locale') {
                        context.read<LocaleCubit>().toggleLocale();
                      } else if (value == 'logout') {
                        context.read<AuthBloc>().add(AuthLogoutRequested());
                      }
                    },
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            enabled: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ?? 'User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  user?.email ?? '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          if (isCompact) ...[
                            PopupMenuItem(
                              value: 'theme',
                              child: Text(l10n.toggleTheme),
                            ),
                            PopupMenuItem(
                              value: 'locale',
                              child: Text(l10n.toggleLanguage),
                            ),
                          ],
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
              body:
                  useRail
                      ? Row(
                        children: [
                          NavigationRail(
                            selectedIndex: _selectedIndex,
                            onDestinationSelected:
                                (i) => setState(() => _selectedIndex = i),
                            labelType: NavigationRailLabelType.all,
                            groupAlignment: -0.85,
                            destinations:
                                screens
                                    .map(
                                      (screen) => NavigationRailDestination(
                                        icon: Icon(screen.icon),
                                        label: Text(screen.label),
                                      ),
                                    )
                                    .toList(),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: screens[_selectedIndex].screen),
                        ],
                      )
                      : screens[_selectedIndex].screen,
              bottomNavigationBar:
                  useRail
                      ? null
                      : NavigationBar(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected:
                            (i) => setState(() => _selectedIndex = i),
                        labelBehavior:
                            NavigationDestinationLabelBehavior.onlyShowSelected,
                        destinations:
                            screens
                                .map(
                                  (screen) => NavigationDestination(
                                    icon: Icon(screen.icon),
                                    label: screen.label,
                                  ),
                                )
                                .toList(),
                      ),
            );
          },
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
