import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/order_export_service.dart';
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

String _localizedOrderStatus(AppLocalizations l10n, OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return l10n.statusPending;
    case OrderStatus.approved:
      return l10n.statusApproved;
    case OrderStatus.rejected:
      return l10n.statusRejected;
    case OrderStatus.delivered:
      return l10n.statusDelivered;
  }
}

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
        } else if (state is OrderInsufficientStock) {
          _showInsufficientStockBottomSheet(context, state.items);
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
                      hint: l10n.searchOrders,
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
                      label: Text(_localizedOrderStatus(l10n, status)),
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
                    label: Text(l10n.newOrder),
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
                DataColumn(label: Text(l10n.createdByLabel)),
                DataColumn(label: Text(l10n.modifiedByLabel)),
                DataColumn(label: Text(l10n.actions)),
              ],
              rows:
                  state.filteredOrders.map((order) {
                    return DataRow(
                      cells: [
                        DataCell(Text('#${order.id.substring(0, 8)}')),
                        DataCell(Text(order.shopName)),
                        DataCell(Text(l10n.itemsCount(order.items.length))),
                        DataCell(
                          Text(
                            '\$${order.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(_buildStatusBadge(l10n, order.status)),
                        DataCell(
                          Text(
                            dateFmt.format(order.createdAt),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(Text(order.createdBy.isNotEmpty ? order.createdBy : '-')),
                        DataCell(Text(order.modifiedBy.isNotEmpty ? order.modifiedBy : '-')),
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
                                tooltip: l10n.viewDetails,
                                onPressed:
                                    () => _showOrderDetails(context, order),
                              ),
                              if (order.status == OrderStatus.approved)
                                (state is OrderLoaded &&
                                        state.deliveringOrderIds.contains(order.id))
                                    ? const SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppTheme.infoColor,
                                            ),
                                          ),
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.local_shipping_outlined,
                                          size: 20,
                                          color: AppTheme.infoColor,
                                        ),
                                        tooltip: l10n.markDelivered,
                                        onPressed: () {
                                          context.read<OrderBloc>().add(
                                            OrderMarkDelivered(orderId: order.id),
                                          );
                                        },
                                      ),
                              if (order.status == OrderStatus.pending) ...[
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 20,
                                    color: AppTheme.successColor,
                                  ),
                                  tooltip: l10n.approve,
                                  onPressed: () async {
                                    final confirmed = await ConfirmationDialog.show(
                                      context,
                                      title: l10n.approveOrder,
                                      message: l10n.approveOrderMessage,
                                      confirmLabel: l10n.approve,
                                      confirmColor: AppTheme.successColor,
                                    );
                                    if (confirmed == true && context.mounted) {
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
                                  tooltip: l10n.reject,
                                  onPressed:
                                      () =>
                                          _showRejectDialog(context, order.id),
                                ),
                              ],

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

  Widget _buildStatusBadge(AppLocalizations l10n, OrderStatus status) {
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
    return StatusBadge(label: _localizedOrderStatus(l10n, status), color: color);
  }

  void _showOrderDetails(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => _OrderDetailsDialog(order: order),
    );
  }

  void _showInsufficientStockBottomSheet(
    BuildContext context,
    List<InsufficientStockItem> items,
  ) {
    final sortedItems = List<InsufficientStockItem>.from(items)
      ..sort((a, b) => b.shortage.compareTo(a.shortage));

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: theme.colorScheme.outline, width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.dangerColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Insufficient Stock',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dangerColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'The following products do not have enough stock to fulfill this order. Please increase stock or adjust the order:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedItems.length,
                  itemBuilder: (itemCtx, index) {
                    final item = sortedItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: AppTheme.dangerColor.withValues(alpha: 0.05),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: AppTheme.dangerColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.productName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Available: ${item.available} | Required: ${item.required}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.dangerColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '-${item.shortage}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.dangerColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Needs ${item.shortage} more',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context, String orderId) {
    final l10n = AppLocalizations.of(context)!;
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.rejectOrder),
            content: TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(labelText: l10n.reasonOptional),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
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
                child: Text(l10n.reject),
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
      title: Text(l10n.createNewOrder),
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
                        decoration: InputDecoration(
                          labelText: l10n.selectShop,
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
                          decoration: InputDecoration(
                            labelText: l10n.orderDate,
                            suffixIcon: const Icon(Icons.calendar_today),
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
                          Text(
                            l10n.orderItems,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(l10n.addItem),
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
                                  decoration: InputDecoration(
                                    labelText: l10n.product,
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
                                        decoration: InputDecoration(
                                          labelText: l10n.qty,
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
                                        decoration: InputDecoration(
                                          labelText: l10n.price,
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
                          Text(
                            l10n.totalColon,
                            style: const TextStyle(
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
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed:
              _selectedShop != null && _items.isNotEmpty ? _createOrder : null,
          child: Text(l10n.createOrder),
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

class _OrderDetailsDialog extends StatefulWidget {
  final OrderModel order;

  const _OrderDetailsDialog({required this.order});

  @override
  State<_OrderDetailsDialog> createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends State<_OrderDetailsDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final order = widget.order;
    final dateFmt = DateFormat('MMM dd, yyyy HH:mm');

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('${l10n.orderIdPrefix} #${order.id.substring(0, 8)}')),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_outlined),
            tooltip: l10n.exportOrder,
            onSelected: (value) => _handleExport(value, order),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined,
                        size: 20, color: AppTheme.dangerColor),
                    const SizedBox(width: 8),
                    Text(l10n.exportPdf),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'image',
                child: Row(
                  children: [
                    const Icon(Icons.image_outlined,
                        size: 20, color: AppTheme.infoColor),
                    const SizedBox(width: 8),
                    Text(l10n.exportImage),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: _exporting
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: Container(
                    color: Theme.of(context).dialogTheme.backgroundColor ??
                        Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _infoRow(l10n.shop, order.shopName),
                        _infoRow(l10n.status,
                            _localizedOrderStatus(l10n, order.status)),
                        _infoRow(l10n.total,
                            '\$${order.totalPrice.toStringAsFixed(2)}'),
                        _infoRow(
                          l10n.date,
                          dateFmt.format(order.createdAt),
                        ),
                        if (order.createdBy.isNotEmpty)
                          _infoRow(l10n.createdByLabel, order.createdBy),
                        if (order.modifiedBy.isNotEmpty)
                          _infoRow(l10n.modifiedByLabel, order.modifiedBy),
                        if (order.approvedBy != null)
                          _infoRow(l10n.approvedBy, order.approvedBy!),
                        if (order.rejectionReason != null)
                          _infoRow(
                              l10n.rejectionReason, order.rejectionReason!),
                        if (order.notes != null)
                          _infoRow(l10n.notes, order.notes!),
                        const Divider(),
                        Text(
                          '${l10n.items}:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        // Items table
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(3),
                            1: FixedColumnWidth(50),
                            2: FlexColumnWidth(1.5),
                            3: FlexColumnWidth(1.5),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              children: [
                                _tableHeader(l10n.product),
                                _tableHeader(l10n.qty),
                                _tableHeader(l10n.unitPrice),
                                _tableHeader(l10n.subtotal),
                              ],
                            ),
                            ...order.items.map(
                              (item) => TableRow(
                                children: [
                                  _tableCell(
                                      '${item.productName} (${item.productSize})'),
                                  _tableCell('${item.quantity}'),
                                  _tableCell(
                                      '\$${item.unitPrice.toStringAsFixed(2)}'),
                                  _tableCell(
                                    '\$${item.total.toStringAsFixed(2)}',
                                    bold: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${l10n.totalColon}\$${order.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
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

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _tableCell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Future<void> _handleExport(String type, OrderModel order) async {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    setState(() => _exporting = true);

    try {
      String? filePath;

      if (type == 'pdf') {
        filePath = await OrderExportService.savePdfToFile(
          order,
          locale: locale,
        );
      } else if (type == 'image') {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() => _exporting = false);
        await Future.delayed(const Duration(milliseconds: 200));
        filePath = await OrderExportService.captureWidgetAsImage(
          _boundaryKey,
          order.id,
        );
      }

      if (!mounted) return;
      setState(() => _exporting = false);

      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.exportSuccess}: $filePath'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.exportFailed),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.exportFailed}: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
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
