import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/shop_model_new.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../data/models/order_model.dart';
import '../../bloc/shop_bloc.dart';
import '../../bloc/shop_event.dart';
import '../../bloc/shop_state.dart';

class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key});

  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ShopBloc>().add(ShopLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShopBloc, ShopState>(
      listener: (context, state) {
        if (state is ShopOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.successColor,
            ),
          );
          context.read<ShopBloc>().add(ShopLoadRequested());
        } else if (state is ShopError) {
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
              Row(
                children: [
                  Expanded(
                    child: SearchField(
                      hint: 'Search shops...',
                      onChanged:
                          (query) => context.read<ShopBloc>().add(
                            ShopSearchRequested(query: query),
                          ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showShopForm(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Shop'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildContent(state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ShopState state) {
    if (state is ShopLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is ShopLoaded) {
      if (state.filteredShops.isEmpty) {
        return EmptyStateWidget(
          icon: Icons.store_outlined,
          title: 'No shops yet',
          subtitle: 'Add your first shop to get started',
          action: ElevatedButton.icon(
            onPressed: () => _showShopForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Shop'),
          ),
        );
      }
      final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
      return Card(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('Login Email')),
                DataColumn(label: Text('Total Purchases'), numeric: true),
                DataColumn(label: Text('Actions')),
              ],
              rows:
                  state.filteredShops.map((shop) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            shop.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(Text(shop.phone)),
                        DataCell(
                          Text(
                            shop.loginEmail ?? '—',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(Text(currFmt.format(shop.totalPurchases))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (shop.loginEmail != null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.key,
                                    size: 20,
                                    color: Colors.deepPurple,
                                  ),
                                  tooltip: 'View Credentials',
                                  onPressed:
                                      () =>
                                          _showCredentialsDialog(context, shop),
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.receipt_long,
                                  size: 20,
                                  color: AppTheme.infoColor,
                                ),
                                tooltip: 'View Transactions',
                                onPressed:
                                    () => _showShopTransactions(context, shop),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 20,
                                  color: AppTheme.warningColor,
                                ),
                                tooltip: 'Order History',
                                onPressed: () => _showShopOrders(context, shop),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: AppTheme.primaryColor,
                                ),
                                tooltip: 'Edit',
                                onPressed:
                                    () => _showShopForm(context, shop: shop),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: AppTheme.dangerColor,
                                ),
                                tooltip: 'Delete',
                                onPressed: () async {
                                  final confirmed = await ConfirmationDialog.show(
                                    context,
                                    title: 'Delete Shop',
                                    message:
                                        'Are you sure you want to delete "${shop.name}"?',
                                    confirmLabel: 'Delete',
                                    confirmColor: AppTheme.dangerColor,
                                  );
                                  if (confirmed == true && mounted) {
                                    context.read<ShopBloc>().add(
                                      ShopDeleteRequested(shopId: shop.id),
                                    );
                                  }
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

  void _showCredentialsDialog(BuildContext context, ShopModel shop) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.key, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text('${shop.name} – Login Credentials'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: SelectableText(shop.loginEmail ?? '—'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outlined),
                    title: const Text('Password'),
                    subtitle: SelectableText(shop.loginPassword ?? '—'),
                  ),
                ],
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

  void _showShopForm(BuildContext context, {ShopModel? shop}) {
    final isEditing = shop != null;
    final nameCtrl = TextEditingController(text: shop?.name ?? '');
    final phoneCtrl = TextEditingController(text: shop?.phone ?? '');
    final addressCtrl = TextEditingController(text: shop?.address ?? '');

    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(isEditing ? 'Edit Shop' : 'Add Shop'),
            content: SizedBox(
              width: 450,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Shop Name',
                        ),
                        validator:
                            (v) =>
                                v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone'),
                        keyboardType: TextInputType.phone,
                        validator:
                            (v) =>
                                v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Address (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Login credentials - only for new shops
                      if (!isEditing) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Shop Login Credentials (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email (Optional)',
                            hintText: 'shop@example.com',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty && !v.contains('@')) {
                              return 'Invalid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Password (Optional)',
                            hintText: 'Min 6 characters',
                            prefixIcon: Icon(Icons.lock_outlined),
                          ),
                          obscureText: true,
                          validator: (v) {
                            if (v != null && v.isNotEmpty && v.length < 6) {
                              return 'Min 6 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final now = DateTime.now();
                    final s = ShopModel(
                      id: shop?.id ?? const Uuid().v4(),
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      address:
                          addressCtrl.text.trim().isNotEmpty
                              ? addressCtrl.text.trim()
                              : null,

                      totalPurchases: shop?.totalPurchases ?? 0,
                      createdAt: shop?.createdAt ?? now,
                      updatedAt: now,
                    );
                    if (isEditing) {
                      context.read<ShopBloc>().add(
                        ShopUpdateRequested(shop: s),
                      );
                    } else {
                      final email = emailCtrl.text.trim();
                      final password = passwordCtrl.text;
                      
                      if (email.isNotEmpty && password.isNotEmpty) {
                        context.read<ShopBloc>().add(
                          ShopAddWithAccountRequested(
                            shop: s,
                            email: email,
                            password: password,
                          ),
                        );
                      } else {
                        context.read<ShopBloc>().add(
                          ShopAddRequested(shop: s),
                        );
                      }
                    }
                    Navigator.pop(ctx);
                  }
                },
                child: Text(isEditing ? 'Update' : 'Add'),
              ),
            ],
          ),
    );
  }

  void _showShopTransactions(BuildContext context, ShopModel shop) {
    final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFmt = DateFormat('MMM dd, yyyy HH:mm');

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Transactions - ${shop.name}'),
            content: SizedBox(
              width: 700,
              height: 500,
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('transactions')
                        .where('shopId', isEqualTo: shop.id)
                        .orderBy('createdAt', descending: true)
                        .limit(50)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('No transactions found'));
                  }
                  final transactions =
                      docs
                          .map((d) => TransactionModel.fromFirestore(d))
                          .toList();
                  return SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Amount'), numeric: true),

                          DataColumn(label: Text('Description')),
                        ],
                        rows:
                            transactions.map((t) {
                              final isCredit = t.type == TransactionType.refund;

                              return DataRow(
                                cells: [
                                  DataCell(Text(dateFmt.format(t.createdAt))),
                                  DataCell(
                                    StatusBadge(
                                      label: t.type.label,
                                      color:
                                          isCredit
                                              ? AppTheme.successColor
                                              : AppTheme.warningColor,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${isCredit ? '+' : '-'}${currFmt.format(t.amount)}',
                                      style: TextStyle(
                                        color:
                                            isCredit
                                                ? AppTheme.successColor
                                                : AppTheme.dangerColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),

                                  DataCell(Text(t.description ?? '-')),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  );
                },
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

  void _showShopOrders(BuildContext context, ShopModel shop) {
    final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFmt = DateFormat('MMM dd, yyyy');

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Order History - ${shop.name}'),
            content: SizedBox(
              width: 700,
              height: 500,
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('orders')
                        .where('shopId', isEqualTo: shop.id)
                        .orderBy('createdAt', descending: true)
                        .limit(50)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('No orders found'));
                  }
                  final orders =
                      docs.map((d) => OrderModel.fromFirestore(d)).toList();
                  return SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Order ID')),
                          DataColumn(label: Text('Items')),
                          DataColumn(label: Text('Total'), numeric: true),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Date')),
                        ],
                        rows:
                            orders.map((o) {
                              Color statusColor;
                              switch (o.status) {
                                case OrderStatus.pending:
                                  statusColor = AppTheme.warningColor;
                                case OrderStatus.approved:
                                  statusColor = AppTheme.successColor;
                                case OrderStatus.rejected:
                                  statusColor = AppTheme.dangerColor;
                                case OrderStatus.delivered:
                                  statusColor = AppTheme.infoColor;
                              }
                              return DataRow(
                                cells: [
                                  DataCell(Text('#${o.id.substring(0, 8)}')),
                                  DataCell(Text('${o.items.length} items')),
                                  DataCell(Text(currFmt.format(o.totalPrice))),
                                  DataCell(
                                    StatusBadge(
                                      label: o.status.label,
                                      color: statusColor,
                                    ),
                                  ),
                                  DataCell(Text(dateFmt.format(o.createdAt))),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  );
                },
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
}
