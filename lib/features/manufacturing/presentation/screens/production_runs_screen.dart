import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/additional_cost.dart';
import '../../../../data/models/manufacturing_mix_model.dart';
import '../../../../data/models/production_run_model.dart';
import '../../../../data/models/raw_material_model.dart';
import '../../bloc/manufacturing_mix_bloc.dart';
import '../../bloc/manufacturing_mix_state.dart';
import '../../bloc/production_run_bloc.dart';
import '../../bloc/production_run_event.dart';
import '../../bloc/production_run_state.dart';
import '../../bloc/raw_material_bloc.dart';
import '../../bloc/raw_material_state.dart';

class ProductionRunsScreen extends StatefulWidget {
  const ProductionRunsScreen({super.key});

  @override
  State<ProductionRunsScreen> createState() => _ProductionRunsScreenState();
}

class _ProductionRunsScreenState extends State<ProductionRunsScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductionRunBloc, ProductionRunState>(
      listener: (context, state) {
        if (state is ProductionRunOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppTheme.successColor,
          ));
          context
              .read<ProductionRunBloc>()
              .add(ProductionRunLoadRequested());
        } else if (state is ProductionRunError) {
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
              _buildSummary(context, state),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () => _showForm(context, null),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.mfgAddRun),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildList(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummary(BuildContext context, ProductionRunState state) {
    if (state is! ProductionRunLoaded) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        _StatCard(
            label: l10n.mfgTotalOutput,
            value: '${state.totalOutput.toStringAsFixed(1)} ${l10n.mfgKg}',
            color: AppTheme.successColor),
        const SizedBox(width: 8),
        _StatCard(
            label: l10n.mfgTotalWaste,
            value: '${state.totalWaste.toStringAsFixed(1)} ${l10n.mfgKg}',
            color: AppTheme.warningColor),
        const SizedBox(width: 8),
        _StatCard(
            label: l10n.mfgTotalCost,
            value: '\$${state.totalCost.toStringAsFixed(2)}',
            color: AppTheme.dangerColor),
        const SizedBox(width: 8),
        _StatCard(
            label: l10n.mfgAvgCostPerKg,
            value: '\$${state.averageCostPerKg.toStringAsFixed(2)}',
            color: AppTheme.infoColor),
      ],
    );
  }

  Widget _buildList(BuildContext context, ProductionRunState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state is ProductionRunLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final runs =
        state is ProductionRunLoaded ? state.runs : <ProductionRunModel>[];
    if (runs.isEmpty) {
      return Center(child: Text(l10n.mfgNoRuns));
    }
    return ListView.builder(
      itemCount: runs.length,
      itemBuilder: (context, i) {
        final r = runs[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  AppTheme.primaryColor.withValues(alpha: 0.1),
              child: const Icon(
                  Icons.precision_manufacturing_outlined,
                  color: AppTheme.primaryColor),
            ),
            title: Text(r.mixName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${r.productName} | ${DateFormat('dd/MM/yyyy').format(r.date)}\n'
              '${l10n.mfgInputLabel}: ${r.inputKg.toStringAsFixed(1)} ${l10n.mfgKg} | ${l10n.mfgOutputLabel}: ${r.outputKg.toStringAsFixed(1)} ${l10n.mfgKg} | ${l10n.mfgWasteLabel}: ${r.wasteKg.toStringAsFixed(1)} ${l10n.mfgKg}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${r.costPerKg.toStringAsFixed(2)} / ${l10n.mfgKg}',
                      style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${l10n.mfgTotalLabel}: \$${r.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.dangerColor),
                  onPressed: () => _confirmDelete(context, r),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showForm(BuildContext context, ProductionRunModel? editing) {
    showDialog(
      context: context,
      builder: (ctx) => _ProductionRunDialog(
        editing: editing,
        mixState: context.read<ManufacturingMixBloc>().state,
        materialState: context.read<RawMaterialBloc>().state,
        onSave: (run) {
          if (editing == null) {
            context
                .read<ProductionRunBloc>()
                .add(ProductionRunAddRequested(run: run));
          } else {
            context
                .read<ProductionRunBloc>()
                .add(ProductionRunUpdateRequested(run: run));
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, ProductionRunModel r) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mfgConfirmDelete),
        content: Text(l10n.mfgDeleteConfirm(r.mixName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor),
            onPressed: () {
              context
                  .read<ProductionRunBloc>()
                  .add(ProductionRunDeleteRequested(id: r.id));
              Navigator.pop(ctx);
            },
            child: Text(l10n.mfgDelete),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: color)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ——— Dialog with live cost calculator ———
class _ProductionRunDialog extends StatefulWidget {
  final ProductionRunModel? editing;
  final ManufacturingMixState mixState;
  final RawMaterialState materialState;
  final ValueChanged<ProductionRunModel> onSave;

  const _ProductionRunDialog({
    required this.editing,
    required this.mixState,
    required this.materialState,
    required this.onSave,
  });

  @override
  State<_ProductionRunDialog> createState() =>
      _ProductionRunDialogState();
}

class _ProductionRunDialogState extends State<_ProductionRunDialog> {
  ManufacturingMixModel? _selectedMix;
  final _inputCtrl = TextEditingController();
  final _outputCtrl = TextEditingController();
  final _techCtrl = TextEditingController();
  final _elecCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  final List<AdditionalCost> _additionalCosts = [];

  // live calc
  double _rawMaterialCost = 0;
  double _totalCost = 0;
  double _costPerKg = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _inputCtrl.text = e.inputKg.toString();
      _outputCtrl.text = e.outputKg.toString();
      _techCtrl.text = e.technicianCost.toString();
      _elecCtrl.text = e.electricityCost.toString();
      _notesCtrl.text = e.notes ?? '';
      _date = e.date;
      _additionalCosts.addAll(e.additionalCosts);
      final mixes = widget.mixState is ManufacturingMixLoaded
          ? (widget.mixState as ManufacturingMixLoaded).all
          : <ManufacturingMixModel>[];
      _selectedMix = mixes.isNotEmpty
          ? mixes.firstWhere((m) => m.id == e.mixId,
              orElse: () => mixes.first)
          : null;
    } else {
      final mixes = widget.mixState is ManufacturingMixLoaded
          ? (widget.mixState as ManufacturingMixLoaded).all
          : <ManufacturingMixModel>[];
      if (mixes.isNotEmpty) _selectedMix = mixes.first;
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _outputCtrl.dispose();
    _techCtrl.dispose();
    _elecCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    final inputKg = double.tryParse(_inputCtrl.text) ?? 0;
    final outputKg = double.tryParse(_outputCtrl.text) ?? 0;
    final tech = double.tryParse(_techCtrl.text) ?? 0;
    final elec = double.tryParse(_elecCtrl.text) ?? 0;
    final addl =
        _additionalCosts.fold(0.0, (s, c) => s + c.amount);

    double rawCost = 0;
    if (_selectedMix != null && inputKg > 0) {
      final materials = widget.materialState is RawMaterialLoaded
          ? (widget.materialState as RawMaterialLoaded).all
          : <RawMaterialModel>[];
      final totalMixKg = _selectedMix!.totalQuantityKg;
      if (totalMixKg > 0) {
        for (final comp in _selectedMix!.components) {
          final mat = materials.cast<RawMaterialModel?>().firstWhere(
              (m) => m?.id == comp.materialId,
              orElse: () => null);
          if (mat != null) {
            rawCost +=
                (comp.quantityKg / totalMixKg) * inputKg * mat.pricePerKg;
          }
        }
      }
    }

    final total = rawCost + tech + elec + addl;
    setState(() {
      _rawMaterialCost = rawCost;
      _totalCost = total;
      _costPerKg = outputKg > 0 ? total / outputKg : 0;
    });
  }

  List<ManufacturingMixModel> get _mixes {
    if (widget.mixState is ManufacturingMixLoaded) {
      return (widget.mixState as ManufacturingMixLoaded).all;
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.editing == null
          ? l10n.mfgAddRun
          : l10n.mfgEditRun),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ManufacturingMixModel>(
                value: _selectedMix,
                decoration:
                    InputDecoration(labelText: l10n.mfgMixLabel),
                items: _mixes
                    .map((m) => DropdownMenuItem(
                        value: m, child: Text(m.name)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedMix = v);
                  _recalculate();
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration:
                        InputDecoration(labelText: l10n.mfgInputQty),
                    onChanged: (_) => _recalculate(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _outputCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration:
                        InputDecoration(labelText: l10n.mfgOutputQty),
                    onChanged: (_) => _recalculate(),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _techCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration:
                        InputDecoration(labelText: l10n.mfgTechCost),
                    onChanged: (_) => _recalculate(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _elecCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration:
                        InputDecoration(labelText: l10n.mfgElecCost),
                    onChanged: (_) => _recalculate(),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                        'التاريخ: ${DateFormat('dd/MM/yyyy').format(_date)}'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _date = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(l10n.mfgChooseDate),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.mfgNotes),
              ),
              const Divider(height: 24),
              // Cost preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _CostRow(
                        label: l10n.mfgRawMaterialCostLabel,
                        value: _rawMaterialCost),
                    _CostRow(
                        label: l10n.mfgTotalCost,
                        value: _totalCost,
                        bold: true),
                    _CostRow(
                        label: l10n.mfgCostPerKgLabel,
                        value: _costPerKg,
                        bold: true,
                        color: AppTheme.primaryColor),
                  ],
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
        ElevatedButton(
          onPressed: () {
            if (_selectedMix == null) return;
            final inputKg = double.tryParse(_inputCtrl.text) ?? 0;
            final outputKg = double.tryParse(_outputCtrl.text) ?? 0;
            if (inputKg <= 0 || outputKg <= 0) return;
            final now = DateTime.now();
            final run = ProductionRunModel(
              id: widget.editing?.id ?? const Uuid().v4(),
              mixId: _selectedMix!.id,
              mixName: _selectedMix!.name,
              productName: _selectedMix!.productName,
              inputKg: inputKg,
              outputKg: outputKg,
              technicianCost:
                  double.tryParse(_techCtrl.text) ?? 0,
              electricityCost:
                  double.tryParse(_elecCtrl.text) ?? 0,
              additionalCosts: _additionalCosts,
              rawMaterialCost: _rawMaterialCost,
              totalCost: _totalCost,
              costPerKg: _costPerKg,
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
              date: _date,
              createdBy: 'admin',
              createdAt: widget.editing?.createdAt ?? now,
            );
            widget.onSave(run);
            Navigator.pop(context);
          },
          child: Text(widget.editing == null ? l10n.mfgAddRun : l10n.mfgSave),
        ),
      ],
    );
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  final Color? color;
  const _CostRow(
      {required this.label,
      required this.value,
      this.bold = false,
      this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('\$${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}
