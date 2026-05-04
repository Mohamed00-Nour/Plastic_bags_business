import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/supplier_model_new.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../data/repositories/supplier_repository.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../bloc/supplier_bloc_new.dart';
import '../../bloc/supplier_event.dart';
import '../../bloc/supplier_state.dart';

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
                      hint: 'Search suppliers...',
                      onChanged: (query) => context
                          .read<SupplierBloc>()
                          .add(SupplierSearchRequested(query: query)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showSupplierForm(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Supplier'),
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
    if (state is SupplierLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is SupplierLoaded) {
      if (state.filteredSuppliers.isEmpty) {
        return EmptyStateWidget(
          icon: Icons.local_shipping_outlined,
          title: 'No suppliers yet',
          subtitle: 'Add your first supplier to get started',
          action: ElevatedButton.icon(
            onPressed: () => _showSupplierForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Supplier'),
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
                DataColumn(label: Text('Address')),
                DataColumn(label: Text('Balance'), numeric: true),
                DataColumn(label: Text('Total Supplied'), numeric: true),
                DataColumn(label: Text('Actions')),
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
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.payment,
                            size: 20, color: AppTheme.successColor),
                        tooltip: 'Record Payment',
                        onPressed: () =>
                            _showPaymentDialog(context, supplier),
                      ),
                      IconButton(
                        icon: const Icon(Icons.receipt_long,
                            size: 20, color: AppTheme.infoColor),
                        tooltip: 'View History',
                        onPressed: () =>
                            _showSupplierHistory(context, supplier),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 20, color: AppTheme.primaryColor),
                        tooltip: 'Edit',
                        onPressed: () =>
                            _showSupplierForm(context, supplier: supplier),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: AppTheme.dangerColor),
                        tooltip: 'Delete',
                        onPressed: () async {
                          final confirmed = await ConfirmationDialog.show(
                            context,
                            title: 'Delete Supplier',
                            message:
                                'Are you sure you want to delete "${supplier.name}"?',
                            confirmLabel: 'Delete',
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
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Supplier' : 'Add Supplier'),
        content: SizedBox(
          width: 450,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Address (optional)'),
                ),
              ],
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
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, SupplierModel supplier) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment to Supplier'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supplier: ${supplier.name}'),
              Text(
                  'Current Balance: \$${supplier.balance.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Description (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
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
                        : 'Payment to supplier',
                    createdBy: 'admin',
                    createdAt: DateTime.now(),
                  ));

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment recorded successfully'),
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
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
  }

  void _showSupplierHistory(BuildContext context, SupplierModel supplier) {
    final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFmt = DateFormat('MMM dd, yyyy HH:mm');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('History - ${supplier.name}'),
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
                return const Center(child: Text('No transactions found'));
              }
              final transactions = docs
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
                      DataColumn(label: Text('Balance'), numeric: true),
                      DataColumn(label: Text('Description')),
                    ],
                    rows: transactions.map((t) {
                      return DataRow(cells: [
                        DataCell(Text(dateFmt.format(t.createdAt))),
                        DataCell(StatusBadge(
                          label: t.type.label,
                          color: t.type == TransactionType.supplierPayment
                              ? AppTheme.successColor
                              : AppTheme.warningColor,
                        )),
                        DataCell(Text(
                          currFmt.format(t.amount),
                          style: const TextStyle(fontWeight: FontWeight.w500),
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
