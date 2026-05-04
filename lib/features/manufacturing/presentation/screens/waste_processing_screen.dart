import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/waste_machine_model.dart';
import '../../../../data/models/waste_processing_run_model.dart';
import '../../bloc/waste_processing_bloc.dart';
import '../../bloc/waste_processing_event.dart';
import '../../bloc/waste_processing_state.dart';

class WasteProcessingScreen extends StatefulWidget {
  const WasteProcessingScreen({super.key});

  @override
  State<WasteProcessingScreen> createState() =>
      _WasteProcessingScreenState();
}

class _WasteProcessingScreenState extends State<WasteProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WasteProcessingBloc, WasteProcessingState>(
      listener: (context, state) {
        if (state is WasteProcessingOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppTheme.successColor,
          ));
          context
              .read<WasteProcessingBloc>()
              .add(WasteProcessingLoadRequested());
        } else if (state is WasteProcessingError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppTheme.dangerColor,
          ));
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            TabBar(
              controller: _tab,
              tabs: const [
                Tab(icon: Icon(Icons.settings_outlined), text: 'الماكينات'),
                Tab(icon: Icon(Icons.recycling_outlined), text: 'التشغيل'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _MachinesTab(state: state),
                  _RunsTab(state: state),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ——— Machines Tab ———
class _MachinesTab extends StatelessWidget {
  final WasteProcessingState state;
  const _MachinesTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final machines =
        state is WasteProcessingLoaded
            ? (state as WasteProcessingLoaded).machines
            : <WasteMachineModel>[];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _showMachineForm(context, null),
              icon: const Icon(Icons.add),
              label: const Text('إضافة ماكينة'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: machines.isEmpty
                ? const Center(child: Text('لا يوجد ماكينات'))
                : ListView.builder(
                    itemCount: machines.length,
                    itemBuilder: (_, i) {
                      final m = machines[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.infoColor
                                .withValues(alpha: 0.1),
                            child: const Icon(
                                Icons.settings_outlined,
                                color: AppTheme.infoColor),
                          ),
                          title: Text(m.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusBadge(
                                label:
                                    m.isActive ? 'نشط' : 'متوقف',
                                color: m.isActive
                                    ? AppTheme.successColor
                                    : AppTheme.dangerColor,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _showMachineForm(context, m),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.dangerColor),
                                onPressed: () =>
                                    _confirmDelete(context, m),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showMachineForm(
      BuildContext context, WasteMachineModel? editing) {
    final nameCtrl =
        TextEditingController(text: editing?.name ?? '');
    bool isActive = editing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(editing == null
              ? 'إضافة ماكينة'
              : 'تعديل ماكينة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'اسم الماكينة')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('نشط'),
                value: isActive,
                onChanged: (v) => setDlg(() => isActive = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final machine = WasteMachineModel(
                  id: editing?.id ?? const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  isActive: isActive,
                  createdAt: editing?.createdAt ?? DateTime.now(),
                );
                if (editing == null) {
                  context.read<WasteProcessingBloc>().add(
                      WasteMachineAddRequested(machine: machine));
                } else {
                  context.read<WasteProcessingBloc>().add(
                      WasteMachineUpdateRequested(machine: machine));
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

  void _confirmDelete(BuildContext context, WasteMachineModel m) {
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
                  .read<WasteProcessingBloc>()
                  .add(WasteMachineDeleteRequested(id: m.id));
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

// ——— Runs Tab ———
class _RunsTab extends StatelessWidget {
  final WasteProcessingState state;
  const _RunsTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final loaded =
        state is WasteProcessingLoaded ? state as WasteProcessingLoaded : null;
    final runs = loaded?.runs ?? <WasteProcessingRunModel>[];
    final machines = loaded?.machines ?? <WasteMachineModel>[];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (loaded != null) ...[
            Row(
              children: [
                _StatChip(
                    label: 'دخل',
                    value: '${loaded.totalInput.toStringAsFixed(1)} كجم',
                    color: AppTheme.infoColor),
                const SizedBox(width: 8),
                _StatChip(
                    label: 'خرج',
                    value:
                        '${loaded.totalOutput.toStringAsFixed(1)} كجم',
                    color: AppTheme.successColor),
                const SizedBox(width: 8),
                _StatChip(
                    label: 'هالك',
                    value: '${loaded.totalLoss.toStringAsFixed(1)} كجم',
                    color: AppTheme.warningColor),
                const SizedBox(width: 8),
                _StatChip(
                    label: 'تكلفة',
                    value:
                        '\$${loaded.totalCost.toStringAsFixed(2)}',
                    color: AppTheme.dangerColor),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: machines.isEmpty
                  ? null
                  : () => _showRunForm(context, null, machines),
              icon: const Icon(Icons.add),
              label: const Text('إضافة تشغيلة'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: runs.isEmpty
                ? const Center(child: Text('لا يوجد تشغيلات'))
                : ListView.builder(
                    itemCount: runs.length,
                    itemBuilder: (_, i) {
                      final r = runs[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.warningColor
                                .withValues(alpha: 0.1),
                            child: const Icon(
                                Icons.recycling_outlined,
                                color: AppTheme.warningColor),
                          ),
                          title: Text(r.machineName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${DateFormat('dd/MM/yyyy').format(r.date)} | '
                            'دخل: ${r.inputKg.toStringAsFixed(1)} → خرج: ${r.outputKg.toStringAsFixed(1)} كجم\n'
                            'النتيجة: ${r.resultType.label}'
                            '${r.resultMaterialName != null ? ' (${r.resultMaterialName})' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${r.costPerKg.toStringAsFixed(2)} / كجم',
                                    style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'إجمالي: \$${r.totalCost.toStringAsFixed(2)}',
                                    style:
                                        const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.dangerColor),
                                onPressed: () =>
                                    _confirmRunDelete(context, r),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showRunForm(BuildContext context, WasteProcessingRunModel? editing,
      List<WasteMachineModel> machines) {
    WasteMachineModel? selectedMachine = editing != null
        ? machines.firstWhere((m) => m.id == editing.machineId,
            orElse: () => machines.first)
        : machines.first;
    final inputCtrl = TextEditingController(
        text: editing != null ? editing.inputKg.toString() : '');
    final outputCtrl = TextEditingController(
        text: editing != null ? editing.outputKg.toString() : '');
    final procCtrl = TextEditingController(
        text: editing != null ? editing.processingCost.toString() : '');
    final transCtrl = TextEditingController(
        text: editing != null ? editing.transportCost.toString() : '');
    final nameCtrl = TextEditingController(
        text: editing?.resultMaterialName ?? '');
    var resultType =
        editing?.resultType ?? WasteResultType.rawMaterial;
    DateTime date = editing?.date ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final inputKg = double.tryParse(inputCtrl.text) ?? 0;
          final outputKg = double.tryParse(outputCtrl.text) ?? 0;
          final proc = double.tryParse(procCtrl.text) ?? 0;
          final trans = double.tryParse(transCtrl.text) ?? 0;
          final total = proc + trans;
          final cpk = outputKg > 0 ? total / outputKg : 0.0;

          return AlertDialog(
            title: Text(editing == null
                ? 'إضافة تشغيلة خرازة'
                : 'تعديل تشغيلة'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<WasteMachineModel>(
                      value: selectedMachine,
                      decoration:
                          const InputDecoration(labelText: 'الماكينة'),
                      items: machines
                          .map((m) => DropdownMenuItem(
                              value: m, child: Text(m.name)))
                          .toList(),
                      onChanged: (v) =>
                          setDlg(() => selectedMachine = v),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: inputCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'الدخل (كجم)'),
                          onChanged: (_) => setDlg(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: outputCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'الخرج (كجم)'),
                          onChanged: (_) => setDlg(() {}),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: procCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'تكلفة التشغيل'),
                          onChanged: (_) => setDlg(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: transCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'تكلفة النقل'),
                          onChanged: (_) => setDlg(() {}),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                            'التاريخ: ${DateFormat('dd/MM/yyyy').format(date)}'),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            final p = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (p != null) setDlg(() => date = p);
                          },
                          icon: const Icon(Icons.calendar_today,
                              size: 16),
                          label: const Text('اختر'),
                        ),
                      ],
                    ),
                    const Divider(),
                    DropdownButtonFormField<WasteResultType>(
                      value: resultType,
                      decoration:
                          const InputDecoration(labelText: 'نتيجة الخرج'),
                      items: WasteResultType.values
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t.label)))
                          .toList(),
                      onChanged: (v) =>
                          setDlg(() => resultType = v!),
                    ),
                    if (resultType ==
                        WasteResultType.rawMaterial) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'اسم الخامة الناتجة'),
                      ),
                    ],
                    const Divider(),
                    Text(
                        'التكلفة الإجمالية: \$${total.toStringAsFixed(2)} | سعر الكيلو: \$${cpk.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor)),
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
                  if (selectedMachine == null ||
                      inputKg <= 0 ||
                      outputKg <= 0) return;
                  final now = DateTime.now();
                  final runId = editing?.id ?? const Uuid().v4();
                  final run = WasteProcessingRunModel(
                    id: runId,
                    machineId: selectedMachine!.id,
                    machineName: selectedMachine!.name,
                    inputKg: inputKg,
                    outputKg: outputKg,
                    processingCost: proc,
                    transportCost: trans,
                    totalCost: total,
                    costPerKg: cpk,
                    resultType: resultType,
                    resultMaterialId: resultType ==
                            WasteResultType.rawMaterial
                        ? '${runId}_material'
                        : null,
                    resultMaterialName: resultType ==
                            WasteResultType.rawMaterial
                        ? nameCtrl.text.trim().isNotEmpty
                            ? nameCtrl.text.trim()
                            : 'هالك مخروز - ${selectedMachine!.name}'
                        : null,
                    date: date,
                    createdBy: 'admin',
                    createdAt: editing?.createdAt ?? now,
                  );
                  if (editing == null) {
                    context
                        .read<WasteProcessingBloc>()
                        .add(WasteRunAddRequested(run: run));
                  } else {
                    context
                        .read<WasteProcessingBloc>()
                        .add(WasteRunUpdateRequested(run: run));
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

  void _confirmRunDelete(
      BuildContext context, WasteProcessingRunModel r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
            'هتحذف تشغيلة "${r.machineName}" بتاريخ ${DateFormat('dd/MM/yyyy').format(r.date)}؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor),
            onPressed: () {
              context
                  .read<WasteProcessingBloc>()
                  .add(WasteRunDeleteRequested(id: r.id));
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: color)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
