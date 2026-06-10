import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/current_user_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/material_supplier_model.dart';
import '../../../../data/models/raw_material_model.dart';
import '../../bloc/material_supplier_bloc.dart';
import '../../bloc/material_supplier_state.dart';
import '../../bloc/raw_material_bloc.dart';
import '../../bloc/raw_material_event.dart';
import '../../bloc/raw_material_state.dart';

class RawMaterialsScreen extends StatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  State<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends State<RawMaterialsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RawMaterialBloc, RawMaterialState>(
      listener: (context, state) {
        if (state is RawMaterialOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppTheme.successColor,
          ));
          context
              .read<RawMaterialBloc>()
              .add(RawMaterialLoadRequested());
        } else if (state is RawMaterialError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppTheme.dangerColor,
          ));
        }
      },
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: l10n.mfgSearchMaterial,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (v) => context
                          .read<RawMaterialBloc>()
                          .add(RawMaterialSearchRequested(query: v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showForm(context, null),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.mfgAddMaterial),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildList(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context, RawMaterialState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state is RawMaterialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = state is RawMaterialLoaded ? state.filtered : [];
    if (items.isEmpty) {
      return Center(child: Text(l10n.mfgNoMaterials));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i] as RawMaterialModel;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  AppTheme.primaryColor.withValues(alpha: 0.1),
              child: const Icon(Icons.science_outlined,
                  color: AppTheme.primaryColor),
            ),
            title: Text(m.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l10n.mfgTypePrefix}: ${m.type}'),
                if (m.supplierName != null && m.supplierName!.isNotEmpty)
                  Text('${l10n.supplier}: ${m.supplierName}'),
                Row(
                  children: [
                    Text(
                      '${l10n.mfgStockQty}: ${m.quantityKg.toStringAsFixed(1)} ${m.unit}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: m.isLowStock
                            ? AppTheme.dangerColor
                            : null,
                      ),
                    ),
                    if (m.isLowStock) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.warning_amber,
                          size: 14, color: AppTheme.dangerColor),
                    ],
                  ],
                ),
                if (m.createdBy.isNotEmpty)
                  Text(
                    '${l10n.createdByLabel}: ${m.createdBy}${m.modifiedBy.isNotEmpty ? ' | ${l10n.modifiedByLabel}: ${m.modifiedBy}' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '\$${m.pricePerKg.toStringAsFixed(2)} / ${m.unit}',
                    style: const TextStyle(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.successColor),
                  tooltip: l10n.increase,
                  onPressed: () => _showQuantityDialog(context, m, true),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppTheme.warningColor),
                  tooltip: l10n.decrease,
                  onPressed: () =>
                      _showQuantityDialog(context, m, false),
                ),
                const SizedBox(width: 4),
                StatusBadge(
                  label: m.isActive ? l10n.mfgActive : l10n.mfgInactive,
                  color: m.isActive
                      ? AppTheme.successColor
                      : AppTheme.dangerColor,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showForm(context, m),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.dangerColor),
                  onPressed: () => _confirmDelete(context, m),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQuantityDialog(
      BuildContext context, RawMaterialModel m, bool isAdd) {
    final l10n = AppLocalizations.of(context)!;
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAdd ? l10n.mfgAddQuantity : l10n.mfgReduceQuantity),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.name} - ${l10n.mfgStockQty}: ${m.quantityKg.toStringAsFixed(1)} ${m.unit}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration:
                    InputDecoration(labelText: '${l10n.quantity} (${m.unit})'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration:
                    InputDecoration(labelText: l10n.noteOptional),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isAdd ? AppTheme.successColor : AppTheme.warningColor,
            ),
            onPressed: () {
              final qty = double.tryParse(qtyCtrl.text) ?? 0;
              if (qty <= 0) return;
              if (!isAdd && qty > m.quantityKg) return;
              final note =
                  noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
              if (isAdd) {
                context.read<RawMaterialBloc>().add(
                    RawMaterialQuantityAddRequested(
                  materialId: m.id,
                  materialName: m.name,
                  quantityKg: qty,
                  currentStock: m.quantityKg,
                  note: note,
                ));
              } else {
                context.read<RawMaterialBloc>().add(
                    RawMaterialQuantityReduceRequested(
                  materialId: m.id,
                  materialName: m.name,
                  quantityKg: qty,
                  currentStock: m.quantityKg,
                  note: note,
                ));
              }
              Navigator.pop(ctx);
            },
            child: Text(isAdd ? l10n.increase : l10n.decrease),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, RawMaterialModel? editing) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl =
        TextEditingController(text: editing?.name ?? '');
    final typeCtrl =
        TextEditingController(text: editing?.type ?? '');
    final priceCtrl = TextEditingController(
        text: editing != null
            ? editing.pricePerKg.toString()
            : '');
    final unitCtrl =
        TextEditingController(text: editing?.unit ?? 'kg');
    final qtyCtrl = TextEditingController(
        text: editing != null
            ? editing.quantityKg.toString()
            : '0');
    final thresholdCtrl = TextEditingController(
        text: editing != null
            ? editing.lowStockThreshold.toString()
            : '0');
    bool isActive = editing?.isActive ?? true;
    String? selectedSupplierId = editing?.supplierId;
    String? selectedSupplierName = editing?.supplierName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final supplierState =
              context.read<MaterialSupplierBloc>().state;
          final suppliers = supplierState is MaterialSupplierLoaded
              ? supplierState.all
                  .where((s) => s.isActive)
                  .toList()
              : <MaterialSupplierModel>[];

          return AlertDialog(
            title: Text(
                editing == null ? l10n.mfgAddMaterial : l10n.mfgEditMaterial),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                            labelText: l10n.mfgMaterialName)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: typeCtrl,
                        decoration: InputDecoration(
                            labelText: l10n.mfgTypeLabel)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                              controller: priceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                  labelText: l10n.mfgPricePerKgLabel)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                              controller: unitCtrl,
                              decoration: InputDecoration(
                                  labelText: l10n.mfgUnitLabel)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                              controller: qtyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                  labelText: l10n.mfgStockQty)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                              controller: thresholdCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                  labelText: l10n.mfgLowStockAlert)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: selectedSupplierId,
                      decoration: InputDecoration(
                          labelText: l10n.mfgMaterialSupplierLabel),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.noSupplier),
                        ),
                        ...suppliers.map((s) => DropdownMenuItem<String?>(
                              value: s.id,
                              child: Text(s.name),
                            )),
                      ],
                      onChanged: (v) {
                        setDlgState(() {
                          selectedSupplierId = v;
                          selectedSupplierName = v != null
                              ? suppliers
                                  .firstWhere((s) => s.id == v)
                                  .name
                              : null;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.mfgActive),
                      value: isActive,
                      onChanged: (v) =>
                          setDlgState(() => isActive = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel)),
              ElevatedButton(
                onPressed: () {
                  final price =
                      double.tryParse(priceCtrl.text) ?? 0;
                  if (nameCtrl.text.trim().isEmpty || price <= 0) return;
                  final now = DateTime.now();
                  final material = RawMaterialModel(
                    id: editing?.id ?? const Uuid().v4(),
                    name: nameCtrl.text.trim(),
                    type: typeCtrl.text.trim(),
                    pricePerKg: price,
                    unit: unitCtrl.text.trim().isEmpty
                        ? 'kg'
                        : unitCtrl.text.trim(),
                    quantityKg:
                        double.tryParse(qtyCtrl.text) ?? 0,
                    lowStockThreshold:
                        double.tryParse(thresholdCtrl.text) ?? 0,
                    supplierId: selectedSupplierId,
                    supplierName: selectedSupplierName,
                    isActive: isActive,
                    createdBy: editing?.createdBy ??
                        CurrentUserService.instance.userName,
                    modifiedBy: editing != null
                        ? CurrentUserService.instance.userName
                        : '',
                    createdAt: editing?.createdAt ?? now,
                    updatedAt: now,
                  );
                  if (editing == null) {
                    context.read<RawMaterialBloc>().add(
                        RawMaterialAddRequested(material: material));
                  } else {
                    context.read<RawMaterialBloc>().add(
                        RawMaterialUpdateRequested(material: material));
                  }
                  Navigator.pop(ctx);
                },
                child: Text(
                    editing == null ? l10n.mfgAddMaterial : l10n.mfgSave),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, RawMaterialModel m) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mfgConfirmDelete),
        content: Text(l10n.mfgDeleteConfirm(m.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor),
            onPressed: () {
              context
                  .read<RawMaterialBloc>()
                  .add(RawMaterialDeleteRequested(id: m.id));
              Navigator.pop(ctx);
            },
            child: Text(l10n.mfgDelete),
          ),
        ],
      ),
    );
  }
}
