import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';

/// Full-screen, step-by-step order placement screen.
/// Designed for maximum simplicity — large touch targets, clear visuals.
class PlaceOrderScreen extends StatefulWidget {
  final String shopId;
  final String shopName;

  const PlaceOrderScreen({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  // Map productId → quantity chosen (0 = not in order)
  final Map<String, int> _quantities = {};
  List<QueryDocumentSnapshot> _products = [];
  bool _loading = true;
  bool _submitting = false;

  final NumberFormat _numFmt = NumberFormat('#,##0.0');

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final snap = await FirebaseFirestore.instance
        .collection('products')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .get();
    if (mounted) {
      setState(() {
        _products = snap.docs;
        _loading = false;
      });
    }
  }

  int _qty(String id) => _quantities[id] ?? 0;

  double get _total {
    double t = 0;
    for (final doc in _products) {
      final qty = _qty(doc.id);
      if (qty > 0) {
        t += qty * (doc.data() as Map<String, dynamic>)['price'].toDouble();
      }
    }
    return t;
  }

  int get _itemCount =>
      _quantities.values.fold(0, (s, q) => s + q);

  bool get _hasItems => _itemCount > 0;

  Future<void> _confirmAndSubmit() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.shopping_bag_rounded,
                color: AppTheme.primaryColor, size: 28),
            const SizedBox(width: 12),
            Text(l10n.confirmOrder,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.confirmOrderMessage,
                    style: const TextStyle(fontSize: 16, height: 1.5)),
                const SizedBox(height: 16),
                // Item list
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      ..._products
                          .where((d) => _qty(d.id) > 0)
                          .map((d) {
                            final data = d.data() as Map<String, dynamic>;
                            final name = data['name'] as String? ?? '';
                            final size = data['size'] as String? ?? '';
                            final price = (data['price'] ?? 0).toDouble();
                            final qty = _qty(d.id);
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$qty',
                                        style: const TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15)),
                                        if (size.isNotEmpty)
                                          Text(size,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _numFmt.format(qty * price),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppTheme.primaryColor),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(),
                      const Divider(height: 1),
                      // Total row
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.total,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              _numFmt.format(_total),
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, false),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(l10n.goBack),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded),
            label: Text(l10n.yesPlaceOrder),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _submitting = true);
    try {
      final orderId = const Uuid().v4();
      final now = DateTime.now();
      final items = _products
          .where((d) => _qty(d.id) > 0)
          .map((d) {
            final data = d.data() as Map<String, dynamic>;
            final qty = _qty(d.id);
            final price = data['price'].toDouble();
            return {
              'productId': d.id,
              'productName': data['name'] ?? '',
              'productSize': data['size'] ?? '',
              'quantity': qty,
              'unitPrice': price,
              'total': qty * price,
            };
          })
          .toList();

      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'shopId': widget.shopId,
        'shopName': widget.shopName,
        'items': items,
        'totalPrice': _total,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context)!.orderPlacedSuccess,
                    style: const TextStyle(fontSize: 15)),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: AppTheme.dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.placeNewOrder,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? _emptyProducts(l10n)
              : _productGrid(l10n),
      bottomNavigationBar: _hasItems
          ? _OrderSummaryBar(
              itemCount: _itemCount,
              total: _total,
              numFmt: _numFmt,
              submitting: _submitting,
              onConfirm: _confirmAndSubmit,
            )
          : null,
    );
  }

  Widget _emptyProducts(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Text(l10n.noProductsAvailable,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _productGrid(AppLocalizations l10n) {
    return Column(
      children: [
        // Hint banner
        Container(
          width: double.infinity,
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.touch_app_rounded,
                  color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.tapProductToAdd,
                  style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _products.length,
            itemBuilder: (context, i) {
              final doc = _products[i];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] as String? ?? '';
              final size = data['size'] as String? ?? '';
              final price = (data['price'] ?? 0).toDouble();
              final stock = (data['stockQuantity'] ?? 0).toInt();
              final qty = _qty(doc.id);
              final inOrder = qty > 0;
              final outOfStock = stock <= 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProductCard(
                  name: name,
                  size: size,
                  price: price,
                  stock: stock,
                  quantity: qty,
                  inOrder: inOrder,
                  outOfStock: outOfStock,
                  numFmt: _numFmt,
                  onAdd: outOfStock
                      ? null
                      : () => setState(() =>
                          _quantities[doc.id] = (_quantities[doc.id] ?? 0) + 1),
                  onIncrement: qty < stock
                      ? () => setState(() => _quantities[doc.id] = qty + 1)
                      : null,
                  onDecrement: qty > 0
                      ? () => setState(() {
                            if (qty - 1 == 0) {
                              _quantities.remove(doc.id);
                            } else {
                              _quantities[doc.id] = qty - 1;
                            }
                          })
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Product card ───────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final String name;
  final String size;
  final double price;
  final int stock;
  final int quantity;
  final bool inOrder;
  final bool outOfStock;
  final NumberFormat numFmt;
  final VoidCallback? onAdd;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const _ProductCard({
    required this.name,
    required this.size,
    required this.price,
    required this.stock,
    required this.quantity,
    required this.inOrder,
    required this.outOfStock,
    required this.numFmt,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: outOfStock
            ? theme.colorScheme.surface
            : inOrder
                ? AppTheme.primaryColor.withValues(alpha: 0.06)
                : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: outOfStock
              ? theme.dividerColor
              : inOrder
                  ? AppTheme.primaryColor
                  : theme.dividerColor.withValues(alpha: 0.5),
          width: inOrder ? 2 : 1,
        ),
        boxShadow: outOfStock
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product icon / avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: outOfStock
                    ? Colors.grey.withValues(alpha: 0.1)
                    : AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.inventory_2_rounded,
                size: 28,
                color: outOfStock ? Colors.grey : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 14),
            // Name + size + price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: outOfStock ? Colors.grey : null,
                    ),
                  ),
                  if (size.isNotEmpty)
                    Text(
                      size,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55)),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    numFmt.format(price),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: outOfStock ? Colors.grey : AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (outOfStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l10n.outOfStock,
                        style: const TextStyle(
                            color: AppTheme.dangerColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Quantity control or Add button
            if (!outOfStock)
              inOrder
                  ? _QuantityControl(
                      quantity: quantity,
                      onDecrement: onDecrement,
                      onIncrement: onIncrement,
                    )
                  : SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: onAdd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 18),
                          elevation: 2,
                        ),
                        child: const Icon(Icons.add_rounded, size: 28),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}

// ── Quantity stepper ───────────────────────────────────────────────────────────

class _QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _QuantityControl({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: Icons.remove_rounded,
            onTap: onDecrement,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add_rounded,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 46,
          height: 52,
          child: Icon(icon,
              color: onTap != null
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.3),
              size: 24),
        ),
      ),
    );
  }
}

// ── Order summary bar ──────────────────────────────────────────────────────────

class _OrderSummaryBar extends StatelessWidget {
  final int itemCount;
  final double total;
  final NumberFormat numFmt;
  final bool submitting;
  final VoidCallback onConfirm;

  const _OrderSummaryBar({
    required this.itemCount,
    required this.total,
    required this.numFmt,
    required this.submitting,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, -3))
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          children: [
            // Cart badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_bag_rounded,
                      color: AppTheme.primaryColor, size: 28),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$itemCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Total
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.orderTotal,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55)),
                  ),
                  Text(
                    numFmt.format(total),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // CTA button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: submitting ? null : onConfirm,
                icon: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 24),
                label: Text(l10n.placeOrder,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
