import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/current_user_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/supplier_model_new.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../data/repositories/supplier_repository.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../bloc/supplier_bloc_new.dart';
import '../../bloc/supplier_event.dart';
import '../../bloc/supplier_state.dart';

String _localizedTransactionType(AppLocalizations l10n, TransactionType type) {
  switch (type) {
    case TransactionType.balanceCharge:
      return l10n.transactionBalanceCharge;
    case TransactionType.purchase:
      return l10n.transactionPurchase;
    case TransactionType.refund:
      return l10n.transactionRefund;
    case TransactionType.supplierPayment:
      return l10n.transactionSupplierPayment;
  }
}

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SupplierBloc>().add(SupplierLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<SupplierBloc, SupplierState>(
      listener: (context, state) {
        if (state is SupplierOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.successColor),
          );
          context.read<SupplierBloc>().add(SupplierLoadRequested());
        } else if (state is SupplierError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.dangerColor),
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
                      hint: l10n.searchSuppliers,
                      onChanged: (query) => context
                          .read<SupplierBloc>()
                          .add(SupplierSearchRequested(query: query)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showSupplierForm(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addSupplier),
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

  Widget _buildContent(SupplierState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state is SupplierLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is SupplierLoaded) {
      if (state.filteredSuppliers.isEmpty) {
        return EmptyStateWidget(
          icon: Icons.local_shipping_outlined,
          title: l10n.noSuppliersYet,
          subtitle: l10n.addFirstSupplierSubtitle,
          action: ElevatedButton.icon(
            onPressed: () => _showSupplierForm(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.addSupplier),
          ),
        );
      }
      final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
      return Card(
        child: HorizontalScrollableTable(
          child: SingleChildScrollView(
            child: DataTable(
              columns: [
                DataColumn(label: Text(l10n.name)),
                DataColumn(label: Text(l10n.phone)),
                DataColumn(label: Text(l10n.address)),
                DataColumn(label: Text(l10n.balance), numeric: true),
                DataColumn(label: Text(l10n.totalSupplied), numeric: true),
                DataColumn(label: Text(l10n.createdByLabel)),
                DataColumn(label: Text(l10n.modifiedByLabel)),
                DataColumn(label: Text(l10n.actions)),
              ],
              rows: state.filteredSuppliers.map((supplier) {
                return DataRow(cells: [
                  DataCell(Text(supplier.name,
                      style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(supplier.phone)),
                  DataCell(Text(supplier.address ?? '-')),
                  DataCell(Text(
                    currFmt.format(supplier.balance),
                    style: TextStyle(
                      color: supplier.balance >= 0
                          ? AppTheme.successColor
                          : AppTheme.dangerColor,
                    ),
                  )),
                  DataCell(Text(currFmt.format(supplier.totalSupplied))),
                  DataCell(Text(supplier.createdBy.isNotEmpty ? supplier.createdBy : '-')),
                  DataCell(Text(supplier.modifiedBy.isNotEmpty ? supplier.modifiedBy : '-')),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.payment,
                            size: 20, color: AppTheme.successColor),
                        tooltip: l10n.recordPayment,
                        onPressed: () =>
                            _showPaymentDialog(context, supplier),
                      ),
                      IconButton(
                        icon: const Icon(Icons.receipt_long,
                            size: 20, color: AppTheme.infoColor),
                        tooltip: l10n.viewHistory,
                        onPressed: () =>
                            _showSupplierHistory(context, supplier),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 20, color: AppTheme.primaryColor),
                        tooltip: l10n.edit,
                        onPressed: () =>
                            _showSupplierForm(context, supplier: supplier),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: AppTheme.dangerColor),
                        tooltip: l10n.delete,
                        onPressed: () async {
                          final confirmed = await ConfirmationDialog.show(
                            context,
                            title: l10n.deleteSupplier,
                            message:
                                l10n.areYouSureDelete(supplier.name),
                            confirmLabel: l10n.delete,
                            confirmColor: AppTheme.dangerColor,
                          );
                          if (confirmed == true && mounted) {
                            context.read<SupplierBloc>().add(
                                  SupplierDeleteRequested(
                                      supplierId: supplier.id),
                                );
                          }
                        },
                      ),
                    ],
                  )),
                ]);
              }).toList(),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showSupplierForm(BuildContext context, {SupplierModel? supplier}) {
    final isEditing = supplier != null;
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final addressCtrl = TextEditingController(text: supplier?.address ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        final dialogL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(isEditing ? dialogL10n.editSupplier : dialogL10n.addSupplier),
          content: SizedBox(
            width: 450,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: dialogL10n.name),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? dialogL10n.required_field : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(labelText: dialogL10n.phone),
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? dialogL10n.required_field : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressCtrl,
                    decoration:
                        InputDecoration(labelText: dialogL10n.addressOptional),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(dialogL10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final now = DateTime.now();
                  final s = SupplierModel(
                    id: supplier?.id ?? const Uuid().v4(),
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    address: addressCtrl.text.trim().isNotEmpty
                        ? addressCtrl.text.trim()
                        : null,
                    balance: supplier?.balance ?? 0,
                    totalSupplied: supplier?.totalSupplied ?? 0,
                    createdAt: supplier?.createdAt ?? now,
                    updatedAt: now,
                  );
                  if (isEditing) {
                    context
                        .read<SupplierBloc>()
                        .add(SupplierUpdateRequested(supplier: s));
                  } else {
                    context
                        .read<SupplierBloc>()
                        .add(SupplierAddRequested(supplier: s));
                  }
                  Navigator.pop(ctx);
                }
              },
              child: Text(isEditing ? dialogL10n.update : dialogL10n.add),
            ),
          ],
        );
      },
    );
  }

  void _showPaymentDialog(BuildContext context, SupplierModel supplier) {
    final l10n = AppLocalizations.of(context)!;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final dialogL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dialogL10n.recordPaymentToSupplier),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dialogL10n.supplierColon(supplier.name)),
                Text(dialogL10n.currentBalanceColon(
                    supplier.balance.toStringAsFixed(2))),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  decoration: InputDecoration(labelText: dialogL10n.amount),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                      labelText: dialogL10n.descriptionOptional),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(dialogL10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount != null && amount > 0) {
                  try {
                    final supplierRepo = context.read<SupplierRepository>();
                    final transactionRepo =
                        context.read<TransactionRepository>();

                    await supplierRepo.updateBalance(
                        supplier.id, -amount);

                    await transactionRepo
                        .addTransaction(TransactionModel(
                      id: const Uuid().v4(),
                      supplierId: supplier.id,
                      supplierName: supplier.name,
                      type: TransactionType.supplierPayment,
                      amount: amount,
                      balanceAfter: supplier.balance - amount,
                      description: descCtrl.text.isNotEmpty
                          ? descCtrl.text
                          : l10n.paymentToSupplier,
                      createdBy: CurrentUserService.instance.userName,
                      createdAt: DateTime.now(),
                    ));

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.paymentRecordedSuccess),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                      context
                          .read<SupplierBloc>()
                          .add(SupplierLoadRequested());
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppTheme.dangerColor,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor),
              child: Text(dialogL10n.recordPayment),
            ),
          ],
        );
      },
    );
  }

  void _showSupplierHistory(BuildContext context, SupplierModel supplier) {
    final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFmt = DateFormat('MMM dd, yyyy HH:mm');

    showDialog(
      context: context,
      builder: (ctx) {
        final dialogL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dialogL10n.historyFor(supplier.name)),
          content: SizedBox(
            width: 700,
            height: 500,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('supplierId', isEqualTo: supplier.id)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(child: Text(dialogL10n.noTransactionsFound));
                }
                final transactions = docs
                    .map((d) => TransactionModel.fromFirestore(d))
                    .toList();
                return HorizontalScrollableTable(
                  minWidth: 700,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: [
                        DataColumn(label: Text(dialogL10n.date)),
                        DataColumn(label: Text(dialogL10n.type)),
                        DataColumn(
                            label: Text(dialogL10n.amount), numeric: true),
                        DataColumn(
                            label: Text(dialogL10n.balance), numeric: true),
                        DataColumn(label: Text(dialogL10n.description)),
                      ],
                      rows: transactions.map((t) {
                        return DataRow(cells: [
                          DataCell(Text(dateFmt.format(t.createdAt))),
                          DataCell(StatusBadge(
                            label: _localizedTransactionType(
                                dialogL10n, t.type),
                            color: t.type == TransactionType.supplierPayment
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                          )),
                          DataCell(Text(
                            currFmt.format(t.amount),
                            style:
                                const TextStyle(fontWeight: FontWeight.w500),
                          )),
                          DataCell(Text(currFmt.format(t.balanceAfter))),
                          DataCell(Text(t.description ?? '-')),
                        ]);
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
              child: Text(dialogL10n.close),
            ),
          ],
        );
      },
    );
  }
}
