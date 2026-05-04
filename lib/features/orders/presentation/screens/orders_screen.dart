import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/order_model.dart';
import '../../../../data/models/shop_model_new.dart';
import '../../../../data/models/product_model_new.dart';
import '../../../../data/repositories/shop_repository.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../bloc/order_bloc.dart';
import '../../bloc/order_event.dart';
import '../../bloc/order_state.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderStatus? _selectedFilter;

  @override
  void initState() {
    super.initState();
    context.read<OrderBloc>().add(OrderLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<OrderBloc, OrderState>(
      listener: (context, state) {
        if (state is OrderOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.successColor,
            ),
          );
          context.read<OrderBloc>().add(OrderLoadRequested());
        } else if (state is OrderError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: SearchField(
                      hint: 'Search orders...',
                      onChanged:
                          (query) => context.read<OrderBloc>().add(
                            OrderSearchRequested(query: query),
                          ),
                    ),
                  ),
                  // Status filter chips
                  ...OrderStatus.values.map((status) {
                    final isSelected = _selectedFilter == status;
                    return FilterChip(
                      label: Text(status.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = selected ? status : null;
                        });
                        context.read<OrderBloc>().add(
                          OrderFilterByStatus(status: selected ? status : null),
                        );
                      },
                    );
                  }),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateOrderDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Order'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildContent(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, OrderState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state is OrderLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is OrderLoaded) {
      if (state.filteredOrders.isEmpty) {
        return EmptyStateWidget(
          icon: Icons.receipt_long_outlined,
          title: l10n.noOrdersFound,
        );
      }
      final dateFmt = DateFormat('MMM dd, yyyy HH:mm');
      return Card(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text(l10n.orderId)),
                DataColumn(label: Text(l10n.shop)),
                DataColumn(label: Text(l10n.items)),
                DataColumn(label: Text(l10n.total), numeric: true),
                DataColumn(label: Text(l10n.status)),
                DataColumn(label: Text(l10n.date)),
                DataColumn(label: Text(l10n.actions)),
              ],
              rows:
                  state.filteredOrders.map((order) {
                    return DataRow(
                      cells: [
                        DataCell(Text('#${order.id.substring(0, 8)}')),
                        DataCell(Text(order.shopName)),
                        DataCell(Text('${order.items.length} items')),
                        DataCell(
                          Text(
                            '\$${order.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(_buildStatusBadge(order.status)),
                        DataCell(
                          Text(
                            dateFmt.format(order.createdAt),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 20,
                                  color: AppTheme.primaryColor,
                                ),
                                tooltip: 'View Details',
                                onPressed:
                                    () => _showOrderDetails(context, order),
                              ),
                              if (order.status == OrderStatus.pending) ...[
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 20,
                                    color: AppTheme.successColor,
                                  ),
                                  tooltip: 'Approve',
                                  onPressed: () async {
                                    final confirmed = await ConfirmationDialog.show(
                                      context,
                                      title: 'Approve Order',
                                      message:
                                          'This will deduct stock and charge the shop balance.',
                                      confirmLabel: 'Approve',
                                      confirmColor: AppTheme.successColor,
                                    );
                                    if (confirmed == true && mounted) {
                                      context.read<OrderBloc>().add(
                                        OrderApproveRequested(
                                          orderId: order.id,
                                          approvedBy: 'admin',
                                        ),
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    size: 20,
                                    color: AppTheme.dangerColor,
                                  ),
                                  tooltip: 'Reject',
                                  onPressed:
                                      () =>
                                          _showRejectDialog(context, order.id),
                                ),
                              ],
                              if (order.status == OrderStatus.approved)
                                IconButton(
                                  icon: const Icon(
                                    Icons.local_shipping_outlined,
                                    size: 20,
                                    color: AppTheme.infoColor,
                                  ),
                                  tooltip: 'Mark Delivered',
                                  onPressed: () {
                                    context.read<OrderBloc>().add(
                                      OrderMarkDelivered(orderId: order.id),
                                    );
                                  },
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
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color color;
    switch (status) {
      case OrderStatus.pending:
        color = AppTheme.warningColor;
        break;
      case OrderStatus.approved:
        color = AppTheme.successColor;
        break;
      case OrderStatus.rejected:
        color = AppTheme.dangerColor;
        break;
      case OrderStatus.delivered:
        color = AppTheme.infoColor;
        break;
    }
    return StatusBadge(label: status.label, color: color);
  }

  void _showOrderDetails(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Order #${order.id.substring(0, 8)}'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _detailRow('Shop', order.shopName),
                    _detailRow('Status', order.status.label),
                    _detailRow(
                      'Total',
                      '\$${order.totalPrice.toStringAsFixed(2)}',
                    ),
                    _detailRow(
                      'Date',
                      DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt),
                    ),
                    if (order.approvedBy != null)
                      _detailRow('Approved By', order.approvedBy!),
                    if (order.rejectionReason != null)
                      _detailRow('Rejection Reason', order.rejectionReason!),
                    if (order.notes != null) _detailRow('Notes', order.notes!),
                    const Divider(),
                    const Text(
                      'Items:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.productName} (${item.productSize})',
                              ),
                            ),
                            Text('x${item.quantity}'),
                            const SizedBox(width: 16),
                            Text(
                              '\$${item.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, String orderId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Reject Order'),
            content: TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.read<OrderBloc>().add(
                    OrderRejectRequested(
                      orderId: orderId,
                      reason:
                          reasonCtrl.text.isNotEmpty ? reasonCtrl.text : null,
                    ),
                  );
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerColor,
                ),
                child: const Text('Reject'),
              ),
            ],
          ),
    );
  }

  void _showCreateOrderDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const _CreateOrderDialog());
  }
}

class _CreateOrderDialog extends StatefulWidget {
  const _CreateOrderDialog();

  @override
  State<_CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends State<_CreateOrderDialog> {
  ShopModel? _selectedShop;
  DateTime _selectedDate = DateTime.now();
  List<ShopModel> _shops = [];
  List<ProductModel> _products = [];
  final List<_OrderItemEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final shopRepo = context.read<ShopRepository>();
      final productRepo = context.read<ProductRepository>();
      final shopSnap = await shopRepo.searchShops('');
      final prodStream = productRepo.getProducts();
      final prods = await prodStream.first;
      setState(() {
        _shops = shopSnap;
        _products = prods;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _total =>
      _items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: const Text('Create New Order'),
      content: SizedBox(
        width: 800,
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Shop selector
                      DropdownButtonFormField<ShopModel>(
                        value: _selectedShop,
                        decoration: const InputDecoration(
                          labelText: 'Select Shop',
                        ),
                        items:
                            _shops
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.name),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (shop) => setState(() => _selectedShop = shop),
                      ),
                      const SizedBox(height: 16),
                      // Date selector
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (picked != null && picked != _selectedDate) {
                            setState(() {
                              // Preserve current time, just update the date
                              final now = DateTime.now();
                              _selectedDate = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                now.hour,
                                now.minute,
                                now.second,
                              );
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Order Date',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(_selectedDate),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Items
                      Row(
                        children: [
                          const Text(
                            'Order Items',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Item'),
                          ),
                        ],
                      ),
                      ..._items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                DropdownButtonFormField<ProductModel>(
                                  value: item.product,
                                  decoration: const InputDecoration(
                                    labelText: 'Product',
                                    isDense: true,
                                  ),
                                  items:
                                      _products
                                          .map(
                                            (p) => DropdownMenuItem(
                                              value: p,
                                              child: Text(
                                                '${p.name} (${p.size})',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (p) {
                                    setState(() {
                                      item.product = p;
                                      item.priceCtrl.text = (p?.price ?? 0)
                                          .toStringAsFixed(2);
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: item.qtyCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Qty',
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (v) {
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: item.priceCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Price',
                                          isDense: true,
                                          prefixText: '\$ ',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (v) {
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      '\$${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: AppTheme.dangerColor,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          final removedItem = _items.removeAt(
                                            idx,
                                          );
                                          removedItem.dispose();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'Total: ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${_total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              _selectedShop != null && _items.isNotEmpty ? _createOrder : null,
          child: const Text('Create Order'),
        ),
      ],
    );
  }

  void _addItem() {
    setState(() {
      _items.add(_OrderItemEntry());
    });
  }

  void _createOrder() {
    if (_selectedShop == null || _items.isEmpty) return;

    final orderItems =
        _items
            .where((item) => item.product != null && item.quantity > 0)
            .map(
              (item) => OrderItem(
                productId: item.product!.id,
                productName: item.product!.name,
                productSize: item.product!.size,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
              ),
            )
            .toList();

    if (orderItems.isEmpty) return;

    final order = OrderModel(
      id: const Uuid().v4(),
      shopId: _selectedShop!.id,
      shopName: _selectedShop!.name,
      items: orderItems,
      totalPrice: _total,
      createdAt: _selectedDate,
      updatedAt: DateTime.now(),
    );

    context.read<OrderBloc>().add(OrderCreateRequested(order: order));
    Navigator.pop(context);
  }
}

class _OrderItemEntry {
  ProductModel? product;
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController priceCtrl = TextEditingController(text: '0');

  int get quantity => int.tryParse(qtyCtrl.text) ?? 1;
  double get unitPrice => double.tryParse(priceCtrl.text) ?? 0;

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}
