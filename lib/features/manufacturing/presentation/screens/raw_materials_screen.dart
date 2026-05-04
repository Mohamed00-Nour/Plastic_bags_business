import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/raw_material_model.dart';
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
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'بحث عن خامة...',
                        prefixIcon: Icon(Icons.search),
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
                    label: const Text('إضافة خامة'),
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
    if (state is RawMaterialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = state is RawMaterialLoaded ? state.filtered : [];
    if (items.isEmpty) {
      return const Center(child: Text('لا يوجد خامات'));
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
            subtitle: Text('النوع: ${m.type}'),
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
                StatusBadge(
                  label: m.isActive ? 'نشط' : 'غير نشط',
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

  void _showForm(BuildContext context, RawMaterialModel? editing) {
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
    bool isActive = editing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title:
              Text(editing == null ? 'إضافة خامة' : 'تعديل خامة'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'اسم الخامة')),
                const SizedBox(height: 12),
                TextField(
                    controller: typeCtrl,
                    decoration:
                        const InputDecoration(labelText: 'النوع')),
                const SizedBox(height: 12),
                TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'السعر / كيلو')),
                const SizedBox(height: 12),
                TextField(
                    controller: unitCtrl,
                    decoration:
                        const InputDecoration(labelText: 'الوحدة')),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('نشط'),
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
                child: const Text('إلغاء')),
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
                  isActive: isActive,
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
              child: Text(editing == null ? 'إضافة' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, RawMaterialModel m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هتحذف "${m.name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor),
            onPressed: () {
              context
                  .read<RawMaterialBloc>()
                  .add(RawMaterialDeleteRequested(id: m.id));
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
