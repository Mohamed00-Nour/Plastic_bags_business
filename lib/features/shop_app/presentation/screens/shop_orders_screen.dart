import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_state.dart';
import 'place_order_screen.dart';

class ShopOrdersScreen extends StatelessWidget {
  const ShopOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated || state.user.shopId == null) {
          return Center(child: Text(l10n.noShopAssigned));
        }
        final shopId = state.user.shopId!;
        final shopName = state.user.shopName ?? '';
        final dateFormat = DateFormat('MMM dd, yyyy');
        final numFmt = NumberFormat('#,##0.0');

        return Scaffold(
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('shopId', isEqualTo: shopId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = snapshot.data!.docs;
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text(l10n.noOrdersYet,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5))),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final data = orders[index].data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';
                  final total = (data['totalPrice'] ?? 0).toDouble();
                  final items = (data['items'] as List?)?.length ?? 0;
                  final createdAt =
                      (data['createdAt'] as Timestamp?)?.toDate();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ExpansionTile(
                      leading: Icon(
                        _statusIcon(status),
                        color: _statusColor(status),
                      ),
                      title: Text(
                        '${l10n.orderIdPrefix} #${orders[index].id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '$items ${l10n.items} • ${status.toUpperCase()}'
                        '${createdAt != null ? ' • ${dateFormat.format(createdAt)}' : ''}',
                      ),
                      trailing: Text(
                        numFmt.format(total),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      children: [
                        if (data['items'] != null)
                          ...(data['items'] as List).map((item) {
                            final itemMap = item as Map<String, dynamic>;
                            return ListTile(
                              dense: true,
                              title: Text(itemMap['productName'] ?? ''),
                              subtitle: Text(
                                  '${l10n.size}: ${itemMap['productSize'] ?? ''}'),
                              trailing: Text(
                                '${itemMap['quantity']} × ${numFmt.format((itemMap['unitPrice'] ?? 0).toDouble())}',
                              ),
                            );
                          }),
                        if (data['notes'] != null &&
                            data['notes'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Row(
                              children: [
                                const Icon(Icons.note, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(data['notes'])),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaceOrderScreen(
                  shopId: shopId,
                  shopName: shopName,
                ),
              ),
            ),
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: Text(l10n.newOrder),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'delivered':
        return Icons.local_shipping;
      default:
        return Icons.pending;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.successColor;
      case 'rejected':
        return AppTheme.dangerColor;
      case 'delivered':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }
}
