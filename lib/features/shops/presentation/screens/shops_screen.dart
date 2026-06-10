import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/shop_model_new.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../data/models/order_model.dart';
import '../../bloc/shop_bloc.dart';
import '../../bloc/shop_event.dart';
import '../../bloc/shop_state.dart';

String _localizedOrderStatus(AppLocalizations l10n, OrderStatus status) {
  switch (status) {
    case OrderStatus.pending: return l10n.statusPending;
    case OrderStatus.approved: return l10n.statusApproved;
    case OrderStatus.rejected: return l10n.statusRejected;
    case OrderStatus.delivered: return l10n.statusDelivered;
  }
}

String _localizedTransactionType(AppLocalizations l10n, TransactionType type) {
  switch (type) {
    case TransactionType.balanceCharge: return l10n.transactionBalanceCharge;
    case TransactionType.purchase: return l10n.transactionPurchase;
    case TransactionType.refund: return l10n.transactionRefund;
    case TransactionType.supplierPayment: return l10n.transactionSupplierPayment;
  }
}

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
    final l10n = AppLocalizations.of(context)!;
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
                      hint: l10n.searchShops,
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
                    label: Text(l10n.addShop),
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
    final l10n = AppLocalizations.of(context)!;
    if (state is ShopLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is ShopLoaded) {
      if (state.filteredShops.isEmpty) {
        return EmptyStateWidget(
          icon: Icons.store_outlined,
          title: l10n.noShopsYet,
          subtitle: l10n.addFirstShopSubtitle,
          action: ElevatedButton.icon(
            onPressed: () => _showShopForm(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.addShop),
          ),
        );
      }
      final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
      return Card(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text(l10n.name)),
                DataColumn(label: Text(l10n.phone)),
                DataColumn(label: Text(l10n.loginEmail)),
                DataColumn(label: Text(l10n.totalPurchasesLabel), numeric: true),
                DataColumn(label: Text(l10n.createdByLabel)),
                DataColumn(label: Text(l10n.modifiedByLabel)),
                DataColumn(label: Text(l10n.actions)),
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
                        DataCell(Text(shop.createdBy.isNotEmpty ? shop.createdBy : '-')),
                        DataCell(Text(shop.modifiedBy.isNotEmpty ? shop.modifiedBy : '-')),
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
                                  tooltip: l10n.viewCredentials,
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
                                tooltip: l10n.viewTransactions,
                                onPressed:
                                    () => _showShopTransactions(context, shop),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 20,
                                  color: AppTheme.warningColor,
                                ),
                                tooltip: l10n.orderHistoryLabel,
                                onPressed: () => _showShopOrders(context, shop),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: AppTheme.primaryColor,
                                ),
                                tooltip: l10n.edit,
                                onPressed:
                                    () => _showShopForm(context, shop: shop),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: AppTheme.dangerColor,
                                ),
                                tooltip: l10n.delete,
                                onPressed: () async {
                                  final confirmed = await ConfirmationDialog.show(
                                    context,
                                    title: l10n.deleteShop,
                                    message:
                                        l10n.areYouSureDelete(shop.name),
                                    confirmLabel: l10n.delete,
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.key, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(l10n.credentialsFor(shop.name)),
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
                    title: Text(l10n.email),
                    subtitle: SelectableText(shop.loginEmail ?? '—'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outlined),
                    title: Text(l10n.password),
                    subtitle: SelectableText(shop.loginPassword ?? '—'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.close),
              ),
            ],
          ),
    );
  }

  void _showShopForm(BuildContext context, {ShopModel? shop}) {
    final l10n = AppLocalizations.of(context)!;
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
            title: Text(isEditing ? l10n.editShop : l10n.addShop),
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
                        decoration: InputDecoration(
                          labelText: l10n.shopName,
                        ),
                        validator:
                            (v) =>
                                v?.trim().isEmpty == true ? l10n.required_field : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        decoration: InputDecoration(labelText: l10n.phone),
                        keyboardType: TextInputType.phone,
                        validator:
                            (v) =>
                                v?.trim().isEmpty == true ? l10n.required_field : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.addressOptional,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (!isEditing) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            l10n.shopLoginCredentials,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.emailOptional,
                            hintText: l10n.emailHint,
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty && !v.contains('@')) {
                              return l10n.invalidEmail;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.passwordOptional,
                            hintText: l10n.minSixChars,
                            prefixIcon: const Icon(Icons.lock_outlined),
                          ),
                          obscureText: true,
                          validator: (v) {
                            if (v != null && v.isNotEmpty && v.length < 6) {
                              return l10n.minSixChars;
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
                child: Text(l10n.cancel),
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
                child: Text(isEditing ? l10n.update : l10n.add),
              ),
            ],
          ),
    );
  }

  void _showShopTransactions(BuildContext context, ShopModel shop) {
    final l10n = AppLocalizations.of(context)!;
    final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFmt = DateFormat('MMM dd, yyyy HH:mm');

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.transactionsFor(shop.name)),
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
                    return Center(child: Text(l10n.noTransactionsFound));
                  }
                  final transactions =
                      docs
                          .map((d) => TransactionModel.fromFirestore(d))
                          .toList();
                  return SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(l10n.date)),
                          DataColumn(label: Text(l10n.type)),
                          DataColumn(label: Text(l10n.amount), numeric: true),

                          DataColumn(label: Text(l10n.description)),
                        ],
                        rows:
                            transactions.map((t) {
                              final isCredit = t.type == TransactionType.refund;

                              return DataRow(
                                cells: [
                                  DataCell(Text(dateFmt.format(t.createdAt))),
                                  DataCell(
                                    StatusBadge(
                                      label: _localizedTransactionType(l10n, t.type),
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
                child: Text(l10n.close),
              ),
            ],
          ),
    );
  }

  void _showShopOrders(BuildContext context, ShopModel shop) {
    final l10n = AppLocalizations.of(context)!;
    final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFmt = DateFormat('MMM dd, yyyy');

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.orderHistoryFor(shop.name)),
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
                    return Center(child: Text(l10n.noOrdersFound));
                  }
                  final orders =
                      docs.map((d) => OrderModel.fromFirestore(d)).toList();
                  return SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(l10n.orderId)),
                          DataColumn(label: Text(l10n.items)),
                          DataColumn(label: Text(l10n.total), numeric: true),
                          DataColumn(label: Text(l10n.status)),
                          DataColumn(label: Text(l10n.date)),
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
                                  DataCell(Text(l10n.itemsCount(o.items.length))),
                                  DataCell(Text(currFmt.format(o.totalPrice))),
                                  DataCell(
                                    StatusBadge(
                                      label: _localizedOrderStatus(l10n, o.status),
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
                child: Text(l10n.close),
              ),
            ],
          ),
    );
  }
}
