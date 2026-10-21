import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/product_model_new.dart';
import '../../bloc/product_bloc_new.dart';
import '../../bloc/product_event.dart';
import '../../bloc/product_state.dart';

import '../../../../services/product_inventory_pdf_service.dart';

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

  void _exportInventoryAudit(BuildContext context, ProductState state) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    List<ProductModel> products = [];
    if (state is ProductLoaded) {
      products =
          state.filteredProducts.isNotEmpty
              ? state.filteredProducts
              : state.products;
    }

    if (products.isEmpty) {
      final snap =
          await FirebaseFirestore.instance.collection('products').get();
      products =
          snap.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
    }

    if (products.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'لا توجد منتجات لحفظ تقرير الجرد'
                  : 'No products found to audit',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await ProductInventoryPdfService.showInventoryAuditSelectionDialog(
      context: context,
      products: products,
      locale: isArabic ? 'ar' : 'en',
    );
  }

  void _showReorderDialog(BuildContext context, List<ProductModel> products) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final tempList = List<ProductModel>.from(products);
    var isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Container(
                width: 680,
                height: 720,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title & Description
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.swap_vert_rounded,
                            color: Color(0xFF818CF8),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isArabic
                                    ? 'ترتيب ظهور المنتجات'
                                    : 'Reorder Products Order',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isArabic
                                    ? 'اسحب المنتجات أو استخدم الأسهم لضبط ترتيب ظهورها في الفواتير والقوائم'
                                    : 'Drag items or use arrow buttons to set display order in invoices and lists',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick Sorting helper buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFCBD5E1),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          icon: const Icon(Icons.sort_by_alpha_rounded, size: 16),
                          label: Text(
                            isArabic ? 'ترتيب أبجدي (أ-ي)' : 'Alphabetical (A-Z)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: isSaving
                              ? null
                              : () {
                                  setDialogState(() {
                                    tempList.sort((a, b) => a.name.compareTo(b.name));
                                  });
                                },
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFCBD5E1),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          icon: const Icon(Icons.inventory_2_outlined, size: 16),
                          label: Text(
                            isArabic ? 'الأعلى مخزوناً' : 'Highest Stock',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: isSaving
                              ? null
                              : () {
                                  setDialogState(() {
                                    tempList.sort((a, b) => b.stockQuantity.compareTo(a.stockQuantity));
                                  });
                                },
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFCBD5E1),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          icon: const Icon(Icons.attach_money_rounded, size: 16),
                          label: Text(
                            isArabic ? 'الأعلى سعراً' : 'Highest Price',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: isSaving
                              ? null
                              : () {
                                  setDialogState(() {
                                    tempList.sort((a, b) => b.price.compareTo(a.price));
                                  });
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 8),

                    // Reorderable list
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            itemCount: tempList.length,
                            onReorder: (oldIndex, newIndex) {
                              setDialogState(() {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final item = tempList.removeAt(oldIndex);
                                tempList.insert(newIndex, item);
                              });
                            },
                            itemBuilder: (context, index) {
                              final p = tempList[index];
                              return Card(
                                key: ValueKey('reorder_${p.id}'),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: const Color(0xFF0F172A),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: const Color(0xFF334155),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      // Drag Handle
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.drag_indicator_rounded,
                                            color: Color(0xFF94A3B8),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Index Number Badge
                                      Container(
                                        width: 32,
                                        height: 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFFA5B4FC),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Product Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              p.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.white,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${p.size.isNotEmpty ? "${p.size} • " : ""}\$${p.price.toStringAsFixed(2)} • ${isArabic ? "المخزون" : "Stock"}: ${formatQuantity(p.stockQuantity)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Quick Move Buttons
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.vertical_align_top_rounded,
                                          size: 18,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        tooltip: isArabic ? 'نقل للأعلى تماماً' : 'Move to top',
                                        onPressed: index > 0 && !isSaving
                                            ? () {
                                                setDialogState(() {
                                                  final item = tempList.removeAt(index);
                                                  tempList.insert(0, item);
                                                });
                                              }
                                            : null,
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.arrow_upward_rounded,
                                          size: 18,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        tooltip: isArabic ? 'تحريك للأعلى' : 'Move up',
                                        onPressed: index > 0 && !isSaving
                                            ? () {
                                                setDialogState(() {
                                                  final item = tempList.removeAt(index);
                                                  tempList.insert(index - 1, item);
                                                });
                                              }
                                            : null,
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.arrow_downward_rounded,
                                          size: 18,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        tooltip: isArabic ? 'تحريك للأسفل' : 'Move down',
                                        onPressed: index < tempList.length - 1 && !isSaving
                                            ? () {
                                                setDialogState(() {
                                                  final item = tempList.removeAt(index);
                                                  tempList.insert(index + 1, item);
                                                });
                                              }
                                            : null,
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.vertical_align_bottom_rounded,
                                          size: 18,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        tooltip: isArabic ? 'نقل للأسفل تماماً' : 'Move to bottom',
                                        onPressed: index < tempList.length - 1 && !isSaving
                                            ? () {
                                                setDialogState(() {
                                                  final item = tempList.removeAt(index);
                                                  tempList.add(item);
                                                });
                                              }
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 12),

                    // Dialog Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                          child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () {
                                  setDialogState(() => isSaving = true);
                                  context.read<ProductBloc>().add(
                                    ProductReorderRequested(
                                      reorderedProducts: tempList,
                                    ),
                                  );
                                  Navigator.pop(dialogCtx);
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline, size: 18),
                          label: Text(
                            isSaving
                                ? (isArabic ? 'جاري الحفظ...' : 'Saving...')
                                : (isArabic ? 'حفظ الترتيب' : 'Save Order'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

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
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 650;
                  if (isMobile) {
                    return Column(
                      children: [
                        SearchField(
                          hint: l10n.searchProducts,
                          onChanged:
                              (query) => context.read<ProductBloc>().add(
                                ProductSearchRequested(query: query),
                              ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                              ),
                              onPressed:
                                  () => _exportInventoryAudit(context, state),
                              icon: const Icon(
                                Icons.inventory_rounded,
                                size: 18,
                              ),
                              label: Text(
                                isArabic ? 'جرد المنتجات' : 'Stock Audit',
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                              ),
                              onPressed:
                                  state is ProductLoaded &&
                                          state.products.isNotEmpty
                                      ? () => _showReorderDialog(
                                        context,
                                        state.products,
                                      )
                                      : null,
                              icon: const Icon(
                                Icons.swap_vert_rounded,
                                size: 18,
                              ),
                              label: Text(
                                isArabic ? 'ترتيب المنتجات' : 'Reorder',
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showProductForm(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(l10n.addProduct),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
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
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _exportInventoryAudit(context, state),
                        icon: const Icon(Icons.inventory_rounded, size: 18),
                        label: Text(isArabic ? 'جرد المنتجات' : 'Stock Audit'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                        ),
                        onPressed:
                            state is ProductLoaded && state.products.isNotEmpty
                                ? () => _showReorderDialog(
                                  context,
                                  state.products,
                                )
                                : null,
                        icon: const Icon(Icons.swap_vert_rounded, size: 18),
                        label: Text(
                          isArabic ? 'ترتيب المنتجات' : 'Reorder Products',
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _showProductForm(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l10n.addProduct),
                      ),
                    ],
                  );
                },
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
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
        child: HorizontalScrollableTable(
          child: SingleChildScrollView(
            child: DataTable(
              columns: [
                DataColumn(label: Text(isArabic ? '#' : '#'), numeric: true),
                DataColumn(label: Text(l10n.name)),
                DataColumn(label: Text(l10n.size)),
                DataColumn(label: Text(l10n.cost), numeric: true),
                DataColumn(label: Text(l10n.price), numeric: true),
                DataColumn(label: Text(l10n.stock), numeric: true),
                DataColumn(label: Text(l10n.supplier)),
                DataColumn(label: Text(l10n.createdByLabel)),
                DataColumn(label: Text(l10n.modifiedByLabel)),
                DataColumn(label: Text(l10n.actions)),
              ],
              rows:
                  state.filteredProducts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final product = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(
                                color: Color(0xFF818CF8),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
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
                                formatQuantity(product.stockQuantity),
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
                          Text(
                            product.createdBy.isNotEmpty
                                ? product.createdBy
                                : '-',
                          ),
                        ),
                        DataCell(
                          Text(
                            product.modifiedBy.isNotEmpty
                                ? product.modifiedBy
                                : '-',
                          ),
                        ),
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
                                  final confirmed =
                                      await ConfirmationDialog.show(
                                        context,
                                        title: l10n.deleteProduct,
                                        message: l10n.areYouSureDelete(
                                          product.name,
                                        ),
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
    final price1Ctrl = TextEditingController(
      text: product?.price1.toString() ?? product?.price.toString() ?? '',
    );
    final price2Ctrl = TextEditingController(
      text: product?.price2?.toString() ?? '',
    );
    final price3Ctrl = TextEditingController(
      text: product?.price3?.toString() ?? '',
    );
    final costCtrl = TextEditingController(
      text: product?.costPrice.toString() ?? '',
    );
    final stockCtrl = TextEditingController(
      text: product != null ? formatQuantity(product.stockQuantity) : '0',
    );
    final thresholdCtrl = TextEditingController(
      text: product != null ? formatQuantity(product.lowStockThreshold) : '10',
    );
    final formKey = GlobalKey<FormState>();
    String? selectedSupplierId = product?.supplierId;
    String? selectedSupplierName = product?.supplierName;

    bool nameExists(String name) {
      if (name.trim().isEmpty) return false;
      final state = context.read<ProductBloc>().state;
      if (state is! ProductLoaded) return false;
      final lower = name.trim().toLowerCase();
      return state.products.any(
        (p) => p.name.toLowerCase() == lower && p.id != product?.id,
      );
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder:
              (ctx, setDialogState) => AlertDialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
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
                              errorText:
                                  nameExists(nameCtrl.text)
                                      ? l10n.productExistsWarning
                                      : null,
                            ),
                            onChanged: (_) => setDialogState(() {}),
                            validator: (v) {
                              if (v?.trim().isEmpty == true) {
                                return l10n.required_field;
                              }
                              if (nameExists(v!)) {
                                return l10n.productExistsWarning;
                              }
                              return null;
                            },
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
                                  controller: price1Ctrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Selling Price 1 (Default) *',
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
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: price2Ctrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Selling Price 2 (Optional)',
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v != null &&
                                        v.trim().isNotEmpty &&
                                        double.tryParse(v) == null) {
                                      return l10n.invalid_value;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: price3Ctrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Selling Price 3 (Optional)',
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v != null &&
                                        v.trim().isNotEmpty &&
                                        double.tryParse(v) == null) {
                                      return l10n.invalid_value;
                                    }
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
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
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
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
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
                    onPressed:
                        nameExists(nameCtrl.text)
                            ? null
                            : () {
                              if (formKey.currentState!.validate()) {
                                final now = DateTime.now();
                                final p1Val = double.parse(
                                  price1Ctrl.text.trim(),
                                );
                                final p2Val =
                                    price2Ctrl.text.trim().isNotEmpty
                                        ? double.tryParse(
                                          price2Ctrl.text.trim(),
                                        )
                                        : null;
                                final p3Val =
                                    price3Ctrl.text.trim().isNotEmpty
                                        ? double.tryParse(
                                          price3Ctrl.text.trim(),
                                        )
                                        : null;

                                final p = ProductModel(
                                  id: product?.id ?? const Uuid().v4(),
                                  name: nameCtrl.text.trim(),
                                  size: sizeCtrl.text.trim(),
                                  price: p1Val,
                                  costPrice: double.parse(costCtrl.text.trim()),
                                  price1: p1Val,
                                  price2: p2Val,
                                  price3: p3Val,
                                  stockQuantity:
                                      isEditing
                                          ? product.stockQuantity
                                          : double.tryParse(stockCtrl.text) ??
                                              0.0,
                                  supplierId: selectedSupplierId,
                                  supplierName: selectedSupplierName,
                                  lowStockThreshold:
                                      double.tryParse(thresholdCtrl.text) ??
                                      10.0,
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
    final costCtrl = TextEditingController();
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
                      Text(
                        '${l10n.currentStock}: ${formatQuantity(product.stockQuantity)}',
                      ),
                      if (isIncrease)
                        Text(
                          '${l10n.currentAvgCost}: \$${product.costPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.infoColor,
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountCtrl,
                        decoration: InputDecoration(labelText: l10n.quantity),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      if (isIncrease) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: costCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.stockInUnitCostOptional,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ],
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
                    final amount = double.tryParse(amountCtrl.text);
                    if (amount != null && amount > 0) {
                      if (isIncrease) {
                        final unitCost = double.tryParse(costCtrl.text);
                        context.read<ProductBloc>().add(
                          ProductStockIncreased(
                            productId: product.id,
                            amount: amount,
                            unitCost:
                                unitCost != null && unitCost > 0
                                    ? unitCost
                                    : null,
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
