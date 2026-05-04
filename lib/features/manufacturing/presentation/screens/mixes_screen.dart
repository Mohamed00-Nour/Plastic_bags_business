import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/manufacturing_mix_model.dart';
import '../../../../data/models/raw_material_model.dart';
import '../../bloc/manufacturing_mix_bloc.dart';
import '../../bloc/manufacturing_mix_event.dart';
import '../../bloc/manufacturing_mix_state.dart';
import '../../bloc/raw_material_bloc.dart';
import '../../bloc/raw_material_state.dart';

class MixesScreen extends StatefulWidget {
  const MixesScreen({super.key});

  @override
  State<MixesScreen> createState() => _MixesScreenState();
}

class _MixesScreenState extends State<MixesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ManufacturingMixBloc, ManufacturingMixState>(
      listener: (context, state) {
        if (state is ManufacturingMixOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppTheme.successColor,
          ));
          context
              .read<ManufacturingMixBloc>()
              .add(ManufacturingMixLoadRequested());
        } else if (state is ManufacturingMixError) {
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
                        hintText: 'بحث عن خلطة...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => context
                          .read<ManufacturingMixBloc>()
                          .add(ManufacturingMixSearchRequested(query: v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showForm(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة خلطة'),
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

  Widget _buildList(BuildContext context, ManufacturingMixState state) {
    if (state is ManufacturingMixLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final items =
        state is ManufacturingMixLoaded ? state.filtered : <ManufacturingMixModel>[];
    if (items.isEmpty) {
      return const Center(child: Text('لا يوجد خلطات'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor:
                  AppTheme.infoColor.withValues(alpha: 0.1),
              child: const Icon(Icons.blender_outlined,
                  color: AppTheme.infoColor),
            ),
            title: Text(m.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                'منتج: ${m.productName} | إجمالي: ${m.totalQuantityKg.toStringAsFixed(1)} كجم'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusBadge(
                  label: m.isActive ? 'نشط' : 'متوقف',
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
            children: m.components.map((c) {
              final pct = m.totalQuantityKg > 0
                  ? (c.quantityKg / m.totalQuantityKg * 100)
                      .toStringAsFixed(1)
                  : '0';
              return ListTile(
                contentPadding: const EdgeInsets.fromLTRB(32, 0, 16, 0),
                leading: const Icon(Icons.science_outlined, size: 18),
                title: Text(c.materialName),
                trailing: Text('${c.quantityKg} كجم ($pct%)'),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showForm(BuildContext context, ManufacturingMixModel? editing) {
    final nameCtrl =
        TextEditingController(text: editing?.name ?? '');
    final productCtrl =
        TextEditingController(text: editing?.productName ?? '');
    bool isActive = editing?.isActive ?? true;
    final components =
        List<MixComponent>.from(editing?.components ?? []);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final matState =
              context.read<RawMaterialBloc>().state;
          final materials = matState is RawMaterialLoaded
              ? matState.all
                  .where((m) => m.isActive)
                  .toList()
              : <RawMaterialModel>[];

          return AlertDialog(
            title: Text(
                editing == null ? 'إضافة خلطة' : 'تعديل خلطة'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'اسم الخلطة')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: productCtrl,
                        decoration: const InputDecoration(
                            labelText: 'اسم المنتج')),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('نشط'),
                      value: isActive,
                      onChanged: (v) =>
                          setDlgState(() => isActive = v),
                    ),
                    const Divider(),
                    const Text('المكونات',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...components.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final c = entry.value;
                      return _ComponentRow(
                        component: c,
                        materials: materials,
                        onChanged: (nc) => setDlgState(
                            () => components[idx] = nc),
                        onRemove: () => setDlgState(
                            () => components.removeAt(idx)),
                      );
                    }),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        if (materials.isEmpty) return;
                        final mat = materials.first;
                        setDlgState(() => components.add(
                              MixComponent(
                                materialId: mat.id,
                                materialName: mat.name,
                                quantityKg: 0,
                              ),
                            ));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة مكون'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty ||
                      components.isEmpty) return;
                  final now = DateTime.now();
                  final mix = ManufacturingMixModel(
                    id: editing?.id ?? const Uuid().v4(),
                    name: nameCtrl.text.trim(),
                    productName: productCtrl.text.trim(),
                    components: components,
                    isActive: isActive,
                    createdAt: editing?.createdAt ?? now,
                    updatedAt: now,
                  );
                  if (editing == null) {
                    context
                        .read<ManufacturingMixBloc>()
                        .add(ManufacturingMixAddRequested(mix: mix));
                  } else {
                    context
                        .read<ManufacturingMixBloc>()
                        .add(ManufacturingMixUpdateRequested(mix: mix));
                  }
                  Navigator.pop(ctx);
                },
                child:
                    Text(editing == null ? 'إضافة' : 'حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, ManufacturingMixModel m) {
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
              context.read<ManufacturingMixBloc>().add(
                  ManufacturingMixDeleteRequested(id: m.id));
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class _ComponentRow extends StatefulWidget {
  final MixComponent component;
  final List<RawMaterialModel> materials;
  final ValueChanged<MixComponent> onChanged;
  final VoidCallback onRemove;

  const _ComponentRow({
    required this.component,
    required this.materials,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_ComponentRow> createState() => _ComponentRowState();
}

class _ComponentRowState extends State<_ComponentRow> {
  late final TextEditingController _qtyCtrl;
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
        text: widget.component.quantityKg > 0
            ? widget.component.quantityKg.toString()
            : '');
    _selectedId = widget.component.materialId.isNotEmpty &&
            widget.materials
                .any((m) => m.id == widget.component.materialId)
        ? widget.component.materialId
        : (widget.materials.isNotEmpty ? widget.materials.first.id : '');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.materials.isEmpty) {
      return const Text('لا يوجد خامات نشطة');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: _selectedId,
              decoration:
                  const InputDecoration(labelText: 'الخامة'),
              items: widget.materials
                  .map((m) => DropdownMenuItem(
                      value: m.id, child: Text(m.name)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedId = v);
                final mat =
                    widget.materials.firstWhere((m) => m.id == v);
                widget.onChanged(widget.component.copyWith(
                  materialId: v,
                  materialName: mat.name,
                ));
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'الكمية (كجم)'),
              onChanged: (v) {
                final qty = double.tryParse(v) ?? 0;
                widget.onChanged(
                    widget.component.copyWith(quantityKg: qty));
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: AppTheme.dangerColor),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}
