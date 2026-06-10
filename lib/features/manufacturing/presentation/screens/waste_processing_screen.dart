import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/current_user_service.dart';
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
        final l10n = AppLocalizations.of(context)!;
        return Column(
          children: [
            TabBar(
              controller: _tab,
              tabs: [
                Tab(icon: const Icon(Icons.settings_outlined), text: l10n.mfgMachinesTab),
                Tab(icon: const Icon(Icons.recycling_outlined), text: l10n.mfgProductionTab),
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
    final l10n = AppLocalizations.of(context)!;
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
              label: Text(l10n.mfgAddMachine),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: machines.isEmpty
                ? Center(child: Text(l10n.mfgNoMachines))
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
                                    m.isActive ? l10n.mfgActive : l10n.mfgStopped,
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
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl =
        TextEditingController(text: editing?.name ?? '');
    bool isActive = editing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(editing == null
              ? l10n.mfgAddMachine
              : l10n.mfgEditMachine),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.mfgMachineName)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.mfgActive),
                value: isActive,
                onChanged: (v) => setDlg(() => isActive = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel)),
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
              child: Text(editing == null ? l10n.mfgAddMachine : l10n.mfgSave),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WasteMachineModel m) {
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
                  .read<WasteProcessingBloc>()
                  .add(WasteMachineDeleteRequested(id: m.id));
              Navigator.pop(ctx);
            },
            child: Text(l10n.mfgDelete),
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
    final l10n = AppLocalizations.of(context)!;
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
                    label: l10n.mfgInputLabel,
                    value: '${loaded.totalInput.toStringAsFixed(1)} ${l10n.mfgKg}',
                    color: AppTheme.infoColor),
                const SizedBox(width: 8),
                _StatChip(
                    label: l10n.mfgOutputLabel,
                    value: '${loaded.totalOutput.toStringAsFixed(1)} ${l10n.mfgKg}',
                    color: AppTheme.successColor),
                const SizedBox(width: 8),
                _StatChip(
                    label: l10n.mfgWasteLabel,
                    value: '${loaded.totalLoss.toStringAsFixed(1)} ${l10n.mfgKg}',
                    color: AppTheme.warningColor),
                const SizedBox(width: 8),
                _StatChip(
                    label: l10n.mfgProcessingCost,
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
              label: Text(l10n.mfgAddWasteRun),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: runs.isEmpty
                ? Center(child: Text(l10n.mfgNoWasteRuns))
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
                          subtitle: Builder(builder: (bCtx) {
                            final l10n = AppLocalizations.of(bCtx)!;
                            final resultLabel = r.resultType == WasteResultType.rawMaterial
                                ? l10n.mfgWasteNewMaterial
                                : l10n.mfgWasteCostOnly;
                            return Text(
                              '${DateFormat('dd/MM/yyyy').format(r.date)} | '
                              '${l10n.mfgInputLabel}: ${r.inputKg.toStringAsFixed(1)} → ${l10n.mfgOutputLabel}: ${r.outputKg.toStringAsFixed(1)} ${l10n.mfgKg}\n'
                              '${l10n.mfgResultTypeLabel}: $resultLabel'
                              '${r.resultMaterialName != null ? ' (${r.resultMaterialName})' : ''}',
                            );
                          }),
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
                                    '\$${r.costPerKg.toStringAsFixed(2)} / ${l10n.mfgKg}',
                                    style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${l10n.mfgTotalLabel}: \$${r.totalCost.toStringAsFixed(2)}',
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
    final l10n = AppLocalizations.of(context)!;
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
                ? l10n.mfgAddWasteRun
                : l10n.mfgEditWasteRun),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<WasteMachineModel>(
                      value: selectedMachine,
                      decoration:
                          InputDecoration(labelText: l10n.mfgMachineName),
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
                          decoration: InputDecoration(
                              labelText: l10n.mfgInputKgLabel),
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
                          decoration: InputDecoration(
                              labelText: l10n.mfgOutputKgLabel),
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
                          decoration: InputDecoration(
                              labelText: l10n.mfgProcessingCost),
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
                          decoration: InputDecoration(
                              labelText: l10n.mfgTransportCost),
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
                          label: Text(l10n.mfgChooseDate),
                        ),
                      ],
                    ),
                    const Divider(),
                    DropdownButtonFormField<WasteResultType>(
                      value: resultType,
                      decoration:
                          InputDecoration(labelText: l10n.mfgResultTypeLabel),
                      items: WasteResultType.values
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t == WasteResultType.rawMaterial
                                  ? l10n.mfgWasteNewMaterial
                                  : l10n.mfgWasteCostOnly)))
                          .toList(),
                      onChanged: (v) =>
                          setDlg(() => resultType = v!),
                    ),
                    if (resultType ==
                        WasteResultType.rawMaterial) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                            labelText: l10n.mfgResultMaterialName),
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
                  child: Text(l10n.cancel)),
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
                    createdBy: CurrentUserService.instance.userName,
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
                    Text(editing == null ? l10n.mfgAddWasteRun : l10n.mfgSave),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmRunDelete(
      BuildContext context, WasteProcessingRunModel r) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mfgConfirmDelete),
        content: Text(l10n.mfgDeleteConfirm(r.machineName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor),
            onPressed: () {
              context
                  .read<WasteProcessingBloc>()
                  .add(WasteRunDeleteRequested(id: r.id));
              Navigator.pop(ctx);
            },
            child: Text(l10n.mfgDelete),
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
