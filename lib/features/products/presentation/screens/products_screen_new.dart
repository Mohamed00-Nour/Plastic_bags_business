import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/product_model_new.dart';
import '../../bloc/product_bloc_new.dart';
import '../../bloc/product_event.dart';
import '../../bloc/product_state.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProductBloc>().add(ProductLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<ProductBloc, ProductState>(
      listener: (context, state) {
        if (state is ProductOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.successColor,
            ),
          );
          context.read<ProductBloc>().add(ProductLoadRequested());
        } else if (state is ProductError) {
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
              Row(
                children: [
                  Expanded(
                    child: SearchField(
                      hint: l10n.searchProducts,
                      onChanged:
                          (query) => context.read<ProductBloc>().add(
                            ProductSearchRequested(query: query),
                          ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showProductForm(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addProduct),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Product table
              Expanded(child: _buildContent(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, ProductState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state is ProductLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is ProductLoaded) {
      if (state.filteredProducts.isEmpty) {
        return EmptyStateWidget(
          icon: Icons.inventory_2_outlined,
          title:
              state.searchQuery.isNotEmpty
                  ? l10n.noProductsFound
                  : l10n.noProductsYet,
          subtitle: l10n.addFirstProductSubtitle,
          action: ElevatedButton.icon(
            onPressed: () => _showProductForm(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.addProduct),
          ),
        );
      }
      return Card(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text(l10n.name)),
                DataColumn(label: Text(l10n.size)),
                DataColumn(label: Text(l10n.cost), numeric: true),
                DataColumn(label: Text(l10n.price), numeric: true),
                DataColumn(label: Text(l10n.stock), numeric: true),
                DataColumn(label: Text(l10n.supplier)),
                DataColumn(label: Text(l10n.actions)),
              ],
              rows:
                  state.filteredProducts.map((product) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(Text(product.size)),
                        DataCell(
                          Text('\$${product.costPrice.toStringAsFixed(2)}'),
                        ),
                        DataCell(Text('\$${product.price.toStringAsFixed(2)}')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (product.isLowStock)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(
                                    Icons.warning_amber,
                                    size: 16,
                                    color: AppTheme.dangerColor,
                                  ),
                                ),
                              Text(
                                '${product.stockQuantity}',
                                style: TextStyle(
                                  color:
                                      product.isLowStock
                                          ? AppTheme.dangerColor
                                          : null,
                                  fontWeight:
                                      product.isLowStock
                                          ? FontWeight.bold
                                          : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text(product.supplierName ?? '-')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 20,
                                  color: AppTheme.successColor,
                                ),
                                tooltip: l10n.addStock,
                                onPressed:
                                    () => _showStockDialog(
                                      context,
                                      product,
                                      true,
                                    ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 20,
                                  color: AppTheme.warningColor,
                                ),
                                tooltip: l10n.removeStock,
                                onPressed:
                                    () => _showStockDialog(
                                      context,
                                      product,
                                      false,
                                    ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: AppTheme.primaryColor,
                                ),
                                tooltip: l10n.edit,
                                onPressed:
                                    () => _showProductForm(
                                      context,
                                      product: product,
                                    ),
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
                                    title: l10n.deleteProduct,
                                    message:
                                        l10n.areYouSureDelete(product.name),
                                    confirmLabel: l10n.delete,
                                    confirmColor: AppTheme.dangerColor,
                                  );
                                  if (confirmed == true && mounted) {
                                    context.read<ProductBloc>().add(
                                      ProductDeleteRequested(
                                        productId: product.id,
                                      ),
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

  void _showProductForm(BuildContext context, {ProductModel? product}) {
    final isEditing = product != null;
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final sizeCtrl = TextEditingController(text: product?.size ?? '');
    final priceCtrl = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    final costCtrl = TextEditingController(
      text: product?.costPrice.toString() ?? '',
    );
    final stockCtrl = TextEditingController(
      text: product?.stockQuantity.toString() ?? '0',
    );
    final thresholdCtrl = TextEditingController(
      text: product?.lowStockThreshold.toString() ?? '10',
    );
    final formKey = GlobalKey<FormState>();
    String? selectedSupplierId = product?.supplierId;
    String? selectedSupplierName = product?.supplierName;

    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder:
              (ctx, setDialogState) => AlertDialog(
                title: Text(isEditing ? l10n.editProduct : l10n.addProduct),
                content: SizedBox(
                  width: 500,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.name,
                            ),
                            validator:
                                (v) =>
                                    v?.trim().isEmpty == true
                                        ? l10n.required_field
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: sizeCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.size,
                              hintText: l10n.sizeHint,
                            ),
                            validator:
                                (v) =>
                                    v?.trim().isEmpty == true
                                        ? l10n.required_field
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: costCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.costPrice,
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v?.trim().isEmpty == true)
                                      return l10n.required_field;
                                    if (double.tryParse(v!) == null)
                                      return l10n.invalid_value;
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: priceCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.sellingPrice,
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v?.trim().isEmpty == true)
                                      return l10n.required_field;
                                    if (double.tryParse(v!) == null)
                                      return l10n.invalid_value;
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Supplier dropdown
                          StreamBuilder<QuerySnapshot>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('suppliers')
                                    .where('isActive', isEqualTo: true)
                                    .orderBy('name')
                                    .snapshots(),
                            builder: (context, snapshot) {
                              final suppliers = snapshot.data?.docs ?? [];
                              return DropdownButtonFormField<String>(
                                value: selectedSupplierId,
                                decoration: InputDecoration(
                                  labelText: l10n.supplier,
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(l10n.noSupplier),
                                  ),
                                  ...suppliers.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    return DropdownMenuItem<String>(
                                      value: doc.id,
                                      child: Text(data['name'] ?? ''),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedSupplierId = value;
                                    if (value != null) {
                                      final doc = suppliers.firstWhere(
                                        (d) => d.id == value,
                                      );
                                      selectedSupplierName =
                                          (doc.data()
                                              as Map<String, dynamic>)['name'];
                                    } else {
                                      selectedSupplierName = null;
                                    }
                                  });
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: stockCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.initialStock,
                                  ),
                                  keyboardType: TextInputType.number,
                                  enabled: !isEditing,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: thresholdCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.lowStockAlert,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
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
                        final p = ProductModel(
                          id: product?.id ?? const Uuid().v4(),
                          name: nameCtrl.text.trim(),
                          size: sizeCtrl.text.trim(),
                          price: double.parse(priceCtrl.text),
                          costPrice: double.parse(costCtrl.text),
                          stockQuantity:
                              isEditing
                                  ? product.stockQuantity
                                  : int.tryParse(stockCtrl.text) ?? 0,
                          supplierId: selectedSupplierId,
                          supplierName: selectedSupplierName,
                          lowStockThreshold:
                              int.tryParse(thresholdCtrl.text) ?? 10,
                          createdAt: product?.createdAt ?? now,
                          updatedAt: now,
                        );
                        if (isEditing) {
                          context.read<ProductBloc>().add(
                            ProductUpdateRequested(product: p),
                          );
                        } else {
                          context.read<ProductBloc>().add(
                            ProductAddRequested(product: p),
                          );
                        }
                        Navigator.pop(ctx);
                      }
                    },
                    child: Text(isEditing ? l10n.update : l10n.add),
                  ),
                ],
              ),
        );
      },
    );
  }

  void _showStockDialog(
    BuildContext context,
    ProductModel product,
    bool isIncrease,
  ) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? selectedSupplierId;
    String? selectedSupplierName;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final l10n = AppLocalizations.of(context)!;
            return AlertDialog(
              title: Text(isIncrease ? l10n.increaseStock : l10n.decreaseStock),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l10n.product}: ${product.name}'),
                      Text('${l10n.currentStock}: ${product.stockQuantity}'),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.quantity,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.noteOptional,
                        ),
                      ),
                      if (isIncrease) ...[
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('suppliers')
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }
                            final suppliers = snapshot.data?.docs ?? [];
                            return DropdownButtonFormField<String>(
                              value: selectedSupplierId,
                              decoration: InputDecoration(
                                labelText: l10n.supplier,
                              ),
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(l10n.noSupplier),
                                ),
                                ...suppliers.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  return DropdownMenuItem<String>(
                                    value: doc.id,
                                    child: Text(data['name'] ?? ''),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedSupplierId = value;
                                  if (value != null) {
                                    final doc = suppliers.firstWhere(
                                      (d) => d.id == value,
                                    );
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    selectedSupplierName = data['name'];
                                  } else {
                                    selectedSupplierName = null;
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ],
                    ],
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
                    final amount = int.tryParse(amountCtrl.text);
                    if (amount != null && amount > 0) {
                      if (isIncrease) {
                        context.read<ProductBloc>().add(
                          ProductStockIncreased(
                            productId: product.id,
                            amount: amount,
                            note:
                                noteCtrl.text.isNotEmpty ? noteCtrl.text : null,
                            supplierId: selectedSupplierId,
                            supplierName: selectedSupplierName,
                          ),
                        );
                      } else {
                        context.read<ProductBloc>().add(
                          ProductStockDecreased(
                            productId: product.id,
                            amount: amount,
                            note:
                                noteCtrl.text.isNotEmpty ? noteCtrl.text : null,
                          ),
                        );
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isIncrease
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                  ),
                  child: Text(isIncrease ? l10n.increase : l10n.decrease),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
