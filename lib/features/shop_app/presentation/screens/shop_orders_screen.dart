import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_state.dart';

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
            onPressed: () => _showCreateOrderDialog(context, shopId, shopName),
            icon: const Icon(Icons.add),
            label: Text(l10n.newOrder),
          ),
        );
      },
    );
  }

  void _showCreateOrderDialog(
      BuildContext context, String shopId, String shopName) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateShopOrderDialog(
        shopId: shopId,
        shopName: shopName,
      ),
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

class _CreateShopOrderDialog extends StatefulWidget {
  final String shopId;
  final String shopName;

  const _CreateShopOrderDialog({
    required this.shopId,
    required this.shopName,
  });

  @override
  State<_CreateShopOrderDialog> createState() => _CreateShopOrderDialogState();
}

class _CreateShopOrderDialogState extends State<_CreateShopOrderDialog> {
  final List<_OrderItemEntry> _items = [];
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  double get _total =>
      _items.fold(0, (s, i) => s + (i.quantity * i.unitPrice));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final numFmt = NumberFormat('#,##0.0');

    return AlertDialog(
      title: Text(l10n.placeNewOrder),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product picker
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where('isActive', isEqualTo: true)
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final products = snapshot.data!.docs;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l10n.availableProducts}:',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...products.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? '';
                        final size = data['size'] ?? '';
                        final price = (data['price'] ?? 0).toDouble();
                        final stock = (data['stockQuantity'] ?? 0).toInt();
                        final alreadyAdded =
                            _items.any((i) => i.productId == doc.id);
                        return ListTile(
                          dense: true,
                          title: Text('$name ($size)'),
                          subtitle: Text(
                              '${l10n.priceEach}: ${numFmt.format(price)}  •  ${l10n.stockLabel}: $stock'),
                          trailing: alreadyAdded
                              ? const Icon(Icons.check,
                                  color: AppTheme.successColor)
                              : IconButton(
                                  icon: const Icon(Icons.add_circle_outline,
                                      color: AppTheme.primaryColor),
                                  onPressed: stock <= 0
                                      ? null
                                      : () {
                                          setState(() {
                                            _items.add(_OrderItemEntry(
                                              productId: doc.id,
                                              productName: name,
                                              productSize: size,
                                              unitPrice: price,
                                              quantity: 1,
                                              maxStock: stock,
                                            ));
                                          });
                                        },
                                ),
                        );
                      }),
                    ],
                  );
                },
              ),
              if (_items.isNotEmpty) ...[
                const Divider(),
                Text('${l10n.orderItems}:',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ..._items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return ListTile(
                    dense: true,
                    title: Text(item.productName),
                    subtitle: Text(
                        '${numFmt.format(item.unitPrice)} ${l10n.eachUnit}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: item.quantity > 1
                              ? () => setState(() => _items[i].quantity--)
                              : null,
                        ),
                        Text('${item.quantity}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: item.quantity < item.maxStock
                              ? () => setState(() => _items[i].quantity++)
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: AppTheme.dangerColor),
                          onPressed: () =>
                              setState(() => _items.removeAt(i)),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Text(
                  '${l10n.total}: ${numFmt.format(_total)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: InputDecoration(labelText: l10n.notesOptional),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _items.isEmpty || _submitting ? null : _submitOrder,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.placeOrder),
        ),
      ],
    );
  }

  Future<void> _submitOrder() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _submitting = true);
    try {
      final orderId = const Uuid().v4();
      final now = DateTime.now();
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'shopId': widget.shopId,
        'shopName': widget.shopName,
        'items': _items
            .map((i) => {
                  'productId': i.productId,
                  'productName': i.productName,
                  'productSize': i.productSize,
                  'quantity': i.quantity,
                  'unitPrice': i.unitPrice,
                  'total': i.quantity * i.unitPrice,
                })
            .toList(),
        'totalPrice': _total,
        'status': 'pending',
        'notes': _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.orderPlacedSuccess),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _OrderItemEntry {
  final String productId;
  final String productName;
  final String productSize;
  final double unitPrice;
  int quantity;
  final int maxStock;

  _OrderItemEntry({
    required this.productId,
    required this.productName,
    required this.productSize,
    required this.unitPrice,
    required this.quantity,
    required this.maxStock,
  });
}
