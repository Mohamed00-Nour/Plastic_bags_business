import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/current_user_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/material_supplier_model.dart';
import '../../bloc/material_supplier_bloc.dart';
import '../../bloc/material_supplier_event.dart';
import '../../bloc/material_supplier_state.dart';

class MaterialSuppliersScreen extends StatefulWidget {
  const MaterialSuppliersScreen({super.key});

  @override
  State<MaterialSuppliersScreen> createState() =>
      _MaterialSuppliersScreenState();
}

class _MaterialSuppliersScreenState extends State<MaterialSuppliersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MaterialSupplierBloc, MaterialSupplierState>(
      listener: (context, state) {
        if (state is MaterialSupplierOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppTheme.successColor,
          ));
          context
              .read<MaterialSupplierBloc>()
              .add(MaterialSupplierLoadRequested());
        } else if (state is MaterialSupplierError) {
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
                        hintText: l10n.mfgSearchMaterialSupplier,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (v) => context
                          .read<MaterialSupplierBloc>()
                          .add(MaterialSupplierSearchRequested(query: v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showForm(context, null),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.mfgAddMaterialSupplier),
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

  Widget _buildList(BuildContext context, MaterialSupplierState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state is MaterialSupplierLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final items =
        state is MaterialSupplierLoaded ? state.filtered : [];
    if (items.isEmpty) {
      return Center(child: Text(l10n.mfgNoMaterialSuppliers));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final s = items[i] as MaterialSupplierModel;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  AppTheme.primaryColor.withValues(alpha: 0.1),
              child: const Icon(Icons.local_shipping_outlined,
                  color: AppTheme.primaryColor),
            ),
            title: Text(s.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l10n.phone}: ${s.phone}'),
                if (s.address != null && s.address!.isNotEmpty)
                  Text('${l10n.address}: ${s.address}'),
                if (s.createdBy.isNotEmpty)
                  Text(
                    '${l10n.createdByLabel}: ${s.createdBy}${s.modifiedBy.isNotEmpty ? ' | ${l10n.modifiedByLabel}: ${s.modifiedBy}' : ''}',
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
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (s.isActive
                            ? AppTheme.successColor
                            : AppTheme.dangerColor)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.isActive ? l10n.mfgActive : l10n.mfgInactive,
                    style: TextStyle(
                      color: s.isActive
                          ? AppTheme.successColor
                          : AppTheme.dangerColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showForm(context, s),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.dangerColor),
                  onPressed: () => _confirmDelete(context, s),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showForm(BuildContext context, MaterialSupplierModel? editing) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl =
        TextEditingController(text: editing?.name ?? '');
    final phoneCtrl =
        TextEditingController(text: editing?.phone ?? '');
    final addressCtrl =
        TextEditingController(text: editing?.address ?? '');
    bool isActive = editing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(editing == null
              ? l10n.mfgAddMaterialSupplier
              : l10n.mfgEditMaterialSupplier),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration:
                        InputDecoration(labelText: l10n.name)),
                const SizedBox(height: 12),
                TextField(
                    controller: phoneCtrl,
                    decoration:
                        InputDecoration(labelText: l10n.phone)),
                const SizedBox(height: 12),
                TextField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                        labelText: l10n.addressOptional)),
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
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final now = DateTime.now();
                final supplier = MaterialSupplierModel(
                  id: editing?.id ?? const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim().isEmpty
                      ? null
                      : addressCtrl.text.trim(),
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
                  context.read<MaterialSupplierBloc>().add(
                      MaterialSupplierAddRequested(supplier: supplier));
                } else {
                  context.read<MaterialSupplierBloc>().add(
                      MaterialSupplierUpdateRequested(
                          supplier: supplier));
                }
                Navigator.pop(ctx);
              },
              child: Text(editing == null
                  ? l10n.mfgAddMaterialSupplier
                  : l10n.mfgSave),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, MaterialSupplierModel s) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mfgConfirmDelete),
        content: Text(l10n.mfgDeleteConfirm(s.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor),
            onPressed: () {
              context
                  .read<MaterialSupplierBloc>()
                  .add(MaterialSupplierDeleteRequested(id: s.id));
              Navigator.pop(ctx);
            },
            child: Text(l10n.mfgDelete),
          ),
        ],
      ),
    );
  }
}
