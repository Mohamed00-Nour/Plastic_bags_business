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
          context
              .read<WasteProcessingBloc>()
              .add(WasteProcessingLoadRequested());
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
                          onTap: () => _showRunForm(context, r, machines),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.warningColor
                                .withValues(alpha: 0.1),
                            child: const Icon(
                                Icons.recycling_outlined,
                                color: AppTheme.warningColor),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(r.machineName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (r.isExecuted
                                          ? AppTheme.successColor
                                          : AppTheme.warningColor)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  r.isExecuted
                                      ? l10n.mfgStatusExecuted
                                      : l10n.mfgStatusDraft,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: r.isExecuted
                                        ? AppTheme.successColor
                                        : AppTheme.warningColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Builder(builder: (bCtx) {
                            final l10n = AppLocalizations.of(bCtx)!;
                            final resultLabel = r.resultType ==
                                    WasteResultType.rawMaterial
                                ? l10n.mfgWasteNewMaterial
                                : l10n.mfgWasteCostOnly;
                            return Text(
                              '${DateFormat('dd/MM/yyyy').format(r.date)} | '
                              '${l10n.mfgInputLabel}: ${r.inputKg.toStringAsFixed(1)} → ${l10n.mfgOutputLabel}: ${r.effectiveOutputKg.toStringAsFixed(1)} ${l10n.mfgKg}\n'
                              '${l10n.mfgResultTypeLabel}: $resultLabel'
                              '${r.resultType == WasteResultType.rawMaterial ? ' (${WasteProcessingRunModel.heavyMaterialName})' : ''}',
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
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _showRunForm(context, r, machines),
                              ),
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
    showDialog(
      context: context,
      builder: (ctx) => _WasteRunDialog(
        editing: editing,
        machines: machines,
        onSave: (run) {
          if (editing == null) {
            context.read<WasteProcessingBloc>().add(
                  WasteRunAddRequested(run: run),
                );
          } else {
            context.read<WasteProcessingBloc>().add(
                  WasteRunUpdateRequested(run: run),
                );
          }
        },
        onExecute: (run) {
          context.read<WasteProcessingBloc>().add(
                WasteRunUpdateRequested(run: run, execute: true),
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

class _WasteRunDialog extends StatefulWidget {
  final WasteProcessingRunModel? editing;
  final List<WasteMachineModel> machines;
  final ValueChanged<WasteProcessingRunModel> onSave;
  final ValueChanged<WasteProcessingRunModel> onExecute;

  const _WasteRunDialog({
    required this.editing,
    required this.machines,
    required this.onSave,
    required this.onExecute,
  });

  @override
  State<_WasteRunDialog> createState() => _WasteRunDialogState();
}

class _WasteRunDialogState extends State<_WasteRunDialog> {
  WasteMachineModel? _selectedMachine;
  final _inputCtrl = TextEditingController();
  final _outputCtrl = TextEditingController();
  final _procCtrl = TextEditingController();
  final _transCtrl = TextEditingController();
  WasteResultType _resultType = WasteResultType.rawMaterial;
  DateTime _date = DateTime.now();

  bool get _isExecuted =>
      widget.editing?.status == WasteRunStatus.executed;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _selectedMachine = widget.machines.firstWhere(
        (m) => m.id == e.machineId,
        orElse: () => widget.machines.first,
      );
      _inputCtrl.text = e.inputKg.toString();
      _outputCtrl.text = e.outputKg?.toString() ?? '';
      _procCtrl.text = e.processingCost.toString();
      _transCtrl.text = e.transportCost.toString();
      _resultType = e.resultType;
      _date = e.date;
    } else if (widget.machines.isNotEmpty) {
      _selectedMachine = widget.machines.first;
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _outputCtrl.dispose();
    _procCtrl.dispose();
    _transCtrl.dispose();
    super.dispose();
  }

  double get _inputKg => double.tryParse(_inputCtrl.text) ?? 0;

  double get _outputKg => double.tryParse(_outputCtrl.text) ?? 0;

  double get _totalCost {
    final proc = double.tryParse(_procCtrl.text) ?? 0;
    final trans = double.tryParse(_transCtrl.text) ?? 0;
    return proc + trans;
  }

  double get _costPerKg =>
      _outputKg > 0 ? _totalCost / _outputKg : 0;

  bool get _canExecute =>
      _outputCtrl.text.isNotEmpty &&
      _outputKg > 0 &&
      _inputKg > 0 &&
      !_isExecuted;

  WasteProcessingRunModel _buildRun() {
    final now = DateTime.now();
    final outputVal = double.tryParse(_outputCtrl.text);
    return WasteProcessingRunModel(
      id: widget.editing?.id ?? const Uuid().v4(),
      machineId: _selectedMachine!.id,
      machineName: _selectedMachine!.name,
      inputKg: _inputKg,
      outputKg: outputVal,
      processingCost: double.tryParse(_procCtrl.text) ?? 0,
      transportCost: double.tryParse(_transCtrl.text) ?? 0,
      totalCost: _totalCost,
      costPerKg: _costPerKg,
      resultType: _resultType,
      resultMaterialId: widget.editing?.resultMaterialId,
      resultMaterialName: _resultType == WasteResultType.rawMaterial
          ? WasteProcessingRunModel.heavyMaterialName
          : null,
      status: widget.editing?.status ?? WasteRunStatus.draft,
      date: _date,
      createdBy: widget.editing?.createdBy ??
          CurrentUserService.instance.userName,
      modifiedBy: widget.editing != null
          ? CurrentUserService.instance.userName
          : '',
      createdAt: widget.editing?.createdAt ?? now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.editing == null
          ? l10n.mfgAddWasteRun
          : l10n.mfgEditWasteRun),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isExecuted)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.successColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppTheme.successColor, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.mfgExecutedNote,
                          style: const TextStyle(
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              DropdownButtonFormField<WasteMachineModel>(
                value: _selectedMachine,
                decoration: InputDecoration(labelText: l10n.mfgMachineName),
                items: widget.machines
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text(m.name)))
                    .toList(),
                onChanged: _isExecuted
                    ? null
                    : (v) => setState(() => _selectedMachine = v),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration:
                        InputDecoration(labelText: l10n.mfgInputKgLabel),
                    onChanged: (_) => setState(() {}),
                    readOnly: _isExecuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _outputCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration:
                        InputDecoration(labelText: l10n.mfgOutputKgLabel),
                    onChanged: (_) => setState(() {}),
                    readOnly: _isExecuted,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _procCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration:
                        InputDecoration(labelText: l10n.mfgProcessingCost),
                    onChanged: (_) => setState(() {}),
                    readOnly: _isExecuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _transCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration:
                        InputDecoration(labelText: l10n.mfgTransportCost),
                    onChanged: (_) => setState(() {}),
                    readOnly: _isExecuted,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('${l10n.date}: ${DateFormat('dd/MM/yyyy').format(_date)}'),
                  const Spacer(),
                  if (!_isExecuted)
                    TextButton.icon(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (p != null) setState(() => _date = p);
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(l10n.mfgChooseDate),
                    ),
                ],
              ),
              const Divider(),
              DropdownButtonFormField<WasteResultType>(
                value: _resultType,
                decoration:
                    InputDecoration(labelText: l10n.mfgResultTypeLabel),
                items: WasteResultType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t == WasteResultType.rawMaterial
                              ? l10n.mfgWasteNewMaterial
                              : l10n.mfgWasteCostOnly),
                        ))
                    .toList(),
                onChanged: _isExecuted
                    ? null
                    : (v) => setState(() => _resultType = v!),
              ),
              if (_resultType == WasteResultType.rawMaterial) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.infoColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    l10n.mfgWasteHeavyMaterialNote,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.infoColor,
                    ),
                  ),
                ),
              ],
              const Divider(),
              Text(
                '${l10n.mfgTotalCost}: \$${_totalCost.toStringAsFixed(2)} | ${l10n.mfgCostPerKgLabel}: \$${_costPerKg.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel)),
        if (!_isExecuted)
          ElevatedButton(
            onPressed: () {
              if (_selectedMachine == null || _inputKg <= 0) return;
              widget.onSave(_buildRun());
              Navigator.pop(context);
            },
            child: Text(
                widget.editing == null ? l10n.mfgAddWasteRun : l10n.mfgSave),
          ),
        if (!_isExecuted && widget.editing != null && _canExecute)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            onPressed: () {
              widget.onExecute(_buildRun());
              Navigator.pop(context);
            },
            child: Text(l10n.mfgExecuteBtn),
          ),
      ],
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
