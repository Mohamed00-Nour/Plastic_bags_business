import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_state.dart';

class ShopPurchasesScreen extends StatelessWidget {
  const ShopPurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated || state.user.shopId == null) {
          return Center(child: Text(l10n.noOrdersFound));
        }
        final shopId = state.user.shopId!;
        final dateFormat = DateFormat('MMM dd, yyyy');
        final numberFormat = NumberFormat('#,##0.0');

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('shopId', isEqualTo: shopId)
              .where('status', whereIn: ['approved', 'delivered'])
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final purchases = snapshot.data!.docs;

            // Compute total
            double totalAmount = 0;
            for (final doc in purchases) {
              final data = doc.data() as Map<String, dynamic>;
              totalAmount += (data['totalPrice'] ?? 0).toDouble();
            }

            return CustomScrollView(
              slivers: [
                // ── Summary header ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _PurchaseSummaryHeader(
                      totalAmount: totalAmount,
                      ordersCount: purchases.length,
                      l10n: l10n,
                      numberFormat: numberFormat,
                    ),
                  ),
                ),

                // ── Section title ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      l10n.purchaseHistory,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),

                // ── Empty state ─────────────────────────────────────────────
                if (purchases.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(l10n.noPurchasesYet,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              )),
                        ],
                      ),
                    ),
                  )
                else
                  // ── Purchase list ─────────────────────────────────────────
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final data =
                            purchases[index].data() as Map<String, dynamic>;
                        final status = data['status'] ?? '';
                        final total = (data['totalPrice'] ?? 0).toDouble();
                        final items = (data['items'] as List?) ?? [];
                        final createdAt =
                            (data['createdAt'] as Timestamp?)?.toDate();

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Card(
                            child: ExpansionTile(
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: status == 'delivered'
                                      ? AppTheme.successColor
                                          .withValues(alpha: 0.15)
                                      : AppTheme.primaryColor
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  status == 'delivered'
                                      ? Icons.local_shipping_rounded
                                      : Icons.check_circle_rounded,
                                  color: status == 'delivered'
                                      ? AppTheme.successColor
                                      : AppTheme.primaryColor,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                'Order #${purchases[index].id.substring(0, 8).toUpperCase()}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                '${items.length} ${l10n.items}'
                                '${createdAt != null ? '  •  ${dateFormat.format(createdAt)}' : ''}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6)),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    numberFormat.format(total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  _StatusChip(status: status),
                                ],
                              ),
                              children: [
                                const Divider(height: 1),
                                ...items.map((item) {
                                  final itemMap = item as Map<String, dynamic>;
                                  final qty =
                                      (itemMap['quantity'] ?? 0).toInt();
                                  final unitPrice =
                                      (itemMap['unitPrice'] ?? 0).toDouble();
                                  return ListTile(
                                    dense: true,
                                    leading: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                          Icons.inventory_2_outlined,
                                          size: 16,
                                          color: AppTheme.primaryColor),
                                    ),
                                    title: Text(
                                        itemMap['productName'] ?? '',
                                        style: const TextStyle(fontSize: 13)),
                                    subtitle: Text(
                                        'Size: ${itemMap['productSize'] ?? ''}',
                                        style: const TextStyle(fontSize: 11)),
                                    trailing: Text(
                                      '$qty × ${numberFormat.format(unitPrice)}  =  ${numberFormat.format(qty * unitPrice)}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  );
                                }),
                                // Order total row
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.06),
                                    borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(16)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${l10n.total}: ',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        numberFormat.format(total),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: purchases.length,
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Summary header card ────────────────────────────────────────────────────────

class _PurchaseSummaryHeader extends StatelessWidget {
  final double totalAmount;
  final int ordersCount;
  final AppLocalizations l10n;
  final NumberFormat numberFormat;

  const _PurchaseSummaryHeader({
    required this.totalAmount,
    required this.ordersCount,
    required this.l10n,
    required this.numberFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryDark,
          ],
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
                  l10n.totalPurchasesLabel,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  numberFormat.format(totalAmount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '$ordersCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  l10n.ordersCount,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tiny status chip ───────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDelivered = status == 'delivered';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDelivered
            ? AppTheme.successColor.withValues(alpha: 0.15)
            : AppTheme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: isDelivered ? AppTheme.successColor : AppTheme.primaryColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
