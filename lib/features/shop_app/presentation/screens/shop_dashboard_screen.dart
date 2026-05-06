import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_state.dart';
import 'shop_tier_widget.dart';

class ShopDashboardScreen extends StatelessWidget {
  const ShopDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Center(child: CircularProgressIndicator());
        }
        final user = state.user;
        final shopId = user.shopId;

        if (shopId == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.store_mall_directory_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No shop assigned.\nContact your admin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .snapshots(),
          builder: (context, shopSnap) {
            if (!shopSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final shopData =
                shopSnap.data!.data() as Map<String, dynamic>? ?? {};
            final totalPurchases =
                (shopData['totalPurchases'] ?? 0).toDouble();
            final balance = (shopData['balance'] ?? 0).toDouble();
            final numFmt = NumberFormat('#,##0.0');

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('shopId', isEqualTo: shopId)
                  .orderBy('createdAt', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, ordersSnap) {
                final recentOrders = ordersSnap.data?.docs ?? [];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Active announcements ────────────────────────────
                      _AnnouncementBanner(),
                      // ── Welcome header ──────────────────────────────────
                      _WelcomeBanner(
                        name: user.name,
                        shopName: user.shopName ?? l10n.shopDashboard,
                        email: user.email,
                        balance: balance,
                        numFmt: numFmt,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 20),

                      // ── Quick stats row ─────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _QuickStatCard(
                              icon: Icons.shopping_cart_rounded,
                              label: l10n.totalPurchasesLabel,
                              value: numFmt.format(totalPurchases),
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickStatCard(
                              icon: Icons.receipt_long_rounded,
                              label: l10n.orders,
                              value: '${recentOrders.length}+',
                              color: AppTheme.accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Tier card ───────────────────────────────────────
                      ShopTierWidget(totalPurchases: totalPurchases),
                      const SizedBox(height: 24),

                      // ── Recent orders ───────────────────────────────────
                      if (recentOrders.isNotEmpty) ...[
                        Text(
                          l10n.recentOrders,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ...recentOrders.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return _RecentOrderTile(
                              docId: doc.id, data: data, numFmt: numFmt);
                        }),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Welcome banner ─────────────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final String name;
  final String shopName;
  final String email;
  final double balance;
  final NumberFormat numFmt;
  final AppLocalizations l10n;

  const _WelcomeBanner({
    required this.name,
    required this.shopName,
    required this.email,
    required this.balance,
    required this.numFmt,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                l10n.accountBalance,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                numFmt.format(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Quick stat card ────────────────────────────────────────────────────────────

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55))),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent order tile ──────────────────────────────────────────────────────────

class _RecentOrderTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final NumberFormat numFmt;

  const _RecentOrderTile(
      {required this.docId, required this.data, required this.numFmt});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    final total = (data['totalPrice'] ?? 0).toDouble();
    final itemCount = (data['items'] as List?)?.length ?? 0;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final dateStr = createdAt != null
        ? DateFormat('MMM dd, yyyy').format(createdAt)
        : '';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = AppTheme.primaryColor;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'delivered':
        statusColor = AppTheme.successColor;
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'rejected':
        statusColor = AppTheme.dangerColor;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(
          '#${docId.substring(0, 8).toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text('$itemCount items  •  $dateStr',
            style: const TextStyle(fontSize: 11)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              numFmt.format(total),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.primaryColor),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Announcement Banner ────────────────────────────────────────────────────────

class _AnnouncementBanner extends StatelessWidget {
  const _AnnouncementBanner();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .where('active', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] as String? ?? '';
            final message = data['message'] as String? ?? '';
            return _AnnouncementCard(title: title, message: message);
          }).toList(),
        );
      },
    );
  }
}

class _AnnouncementCard extends StatefulWidget {
  final String title;
  final String message;

  const _AnnouncementCard({required this.title, required this.message});

  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6F00).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.message,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: const Icon(Icons.close, color: Colors.white70, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

