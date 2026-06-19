import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/current_user_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/additional_cost.dart';
import '../../../../data/models/custom_run_field.dart';
import '../../../../data/models/manufacturing_mix_model.dart';
import '../../../../data/models/production_run_model.dart';
import '../../../../data/models/production_run_output.dart';
import '../../../../data/models/raw_material_model.dart';
import '../../../../data/models/product_model_new.dart';
import '../../../products/bloc/product_bloc_new.dart';
import '../../../products/bloc/product_event.dart';
import '../../../products/bloc/product_state.dart';
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
  void initState() {
    super.initState();
    context.read<ProductBloc>().add(ProductLoadRequested());
  }

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
          context
              .read<ProductionRunBloc>()
              .add(ProductionRunLoadRequested());
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
              _buildFilterBar(context, state),
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

  Widget _buildFilterBar(BuildContext context, ProductionRunState state) {
    final l10n = AppLocalizations.of(context)!;
    final activePeriod = state is ProductionRunLoaded
        ? state.activePeriod
        : RunFilterPeriod.all;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: l10n.mfgAll,
            selected: activePeriod == RunFilterPeriod.all,
            onTap: () => context.read<ProductionRunBloc>().add(
                const ProductionRunFilterRequested(
                    period: RunFilterPeriod.all)),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: l10n.rangeToday,
            selected: activePeriod == RunFilterPeriod.today,
            onTap: () => context.read<ProductionRunBloc>().add(
                const ProductionRunFilterRequested(
                    period: RunFilterPeriod.today)),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: l10n.rangeThisWeek,
            selected: activePeriod == RunFilterPeriod.thisWeek,
            onTap: () => context.read<ProductionRunBloc>().add(
                const ProductionRunFilterRequested(
                    period: RunFilterPeriod.thisWeek)),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: l10n.rangeThisMonth,
            selected: activePeriod == RunFilterPeriod.thisMonth,
            onTap: () => context.read<ProductionRunBloc>().add(
                const ProductionRunFilterRequested(
                    period: RunFilterPeriod.thisMonth)),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: l10n.customRange,
            selected: activePeriod == RunFilterPeriod.custom,
            onTap: () => _pickCustomRange(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
    );
    if (picked != null && context.mounted) {
      context.read<ProductionRunBloc>().add(ProductionRunFilterRequested(
        period: RunFilterPeriod.custom,
        customStart: picked.start,
        customEnd: picked.end,
      ));
    }
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
        state is ProductionRunLoaded ? state.filteredRuns : <ProductionRunModel>[];
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
                  (r.isExecuted ? AppTheme.successColor : AppTheme.warningColor)
                      .withValues(alpha: 0.1),
              child: Icon(
                  r.isExecuted
                      ? Icons.check_circle_outline
                      : Icons.pending_outlined,
                  color: r.isExecuted
                      ? AppTheme.successColor
                      : AppTheme.warningColor),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(r.mixName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
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
                    r.isExecuted ? l10n.mfgStatusExecuted : l10n.mfgStatusDraft,
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.outputSummary} | ${DateFormat('dd/MM/yyyy').format(r.date)}',
                ),
                Text(
                  '${l10n.mfgInputLabel}: ${r.inputKg.toStringAsFixed(1)} ${l10n.mfgKg}'
                  ' | ${l10n.mfgOutputLabel}: ${r.effectiveOutputKg.toStringAsFixed(1)} ${l10n.mfgKg}'
                  ' | ${l10n.mfgDamagedLabel}: ${r.calculatedDamagedKg.toStringAsFixed(1)} ${l10n.mfgKg}',
                ),
                if (r.createdBy.isNotEmpty)
                  Text(
                    '${l10n.createdByLabel}: ${r.createdBy}${r.modifiedBy.isNotEmpty ? ' | ${l10n.modifiedByLabel}: ${r.modifiedBy}' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
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
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showForm(context, r),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.dangerColor),
                  onPressed: () => _confirmDelete(context, r),
                ),
              ],
            ),
            onTap: () => _showForm(context, r),
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
        onExecute: (run) {
          context
              .read<ProductionRunBloc>()
              .add(ProductionRunExecuteRequested(run: run));
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor
              : AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.primaryColor,
          ),
        ),
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

// --- Dialog with incremental entry + execute ---
class _ProductionRunDialog extends StatefulWidget {
  final ProductionRunModel? editing;
  final ManufacturingMixState mixState;
  final RawMaterialState materialState;
  final ValueChanged<ProductionRunModel> onSave;
  final ValueChanged<ProductionRunModel> onExecute;

  const _ProductionRunDialog({
    required this.editing,
    required this.mixState,
    required this.materialState,
    required this.onSave,
    required this.onExecute,
  });

  @override
  State<_ProductionRunDialog> createState() =>
      _ProductionRunDialogState();
}

class _ProductionRunDialogState extends State<_ProductionRunDialog> {
  ManufacturingMixModel? _selectedMix;
  final _inputCtrl = TextEditingController();
  final _techCtrl = TextEditingController();
  final _elecCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  final List<AdditionalCost> _additionalCosts = [];
  final List<CustomRunField> _customFields = [];
  final List<ProductionRunOutput> _outputs = [];

  double _rawMaterialCost = 0;
  double _totalCost = 0;
  double _costPerKg = 0;
  double _damagedKg = 0;
  double _totalOutputKg = 0;

  bool get _isExecuted =>
      widget.editing?.status == ProductionRunStatus.executed;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _inputCtrl.text = e.inputKg.toString();
      _techCtrl.text = e.technicianCost.toString();
      _elecCtrl.text = e.electricityCost.toString();
      _notesCtrl.text = e.notes ?? '';
      _date = e.date;
      _additionalCosts.addAll(e.additionalCosts);
      _customFields.addAll(e.customFields);
      _outputs.addAll(e.outputs);
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
    _recalculate();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _techCtrl.dispose();
    _elecCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    final inputKg = double.tryParse(_inputCtrl.text) ?? 0;
    final outputKg =
        _outputs.fold(0.0, (sum, o) => sum + o.quantityKg);
    final tech = double.tryParse(_techCtrl.text) ?? 0;
    final elec = double.tryParse(_elecCtrl.text) ?? 0;
    final addl = _additionalCosts.fold(0.0, (s, c) => s + c.amount);
    final customCost =
        _customFields.fold(0.0, (s, f) => s + f.value);

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

    // damaged = input - output
    final damaged = inputKg - outputKg;

    final total = rawCost + tech + elec + addl + customCost;
    setState(() {
      _rawMaterialCost = rawCost;
      _damagedKg = damaged > 0 ? damaged : 0;
      _totalCost = total;
      _costPerKg = outputKg > 0 ? total / outputKg : 0;
      _totalOutputKg = outputKg;
    });
  }

  List<ManufacturingMixModel> get _mixes {
    if (widget.mixState is ManufacturingMixLoaded) {
      return (widget.mixState as ManufacturingMixLoaded).all;
    }
    return [];
  }

  double get _inputKg => double.tryParse(_inputCtrl.text) ?? 0;

  bool get _canExecute => _totalOutputKg > 0 && !_isExecuted;

  ProductionRunModel _buildRun() {
    final now = DateTime.now();
    final inputKg = double.tryParse(_inputCtrl.text) ?? 0;
    final mergedOutputs = mergeProductionRunOutputs(_outputs);
    final totalOutput =
        mergedOutputs.fold(0.0, (sum, o) => sum + o.quantityKg);

    return ProductionRunModel(
      id: widget.editing?.id ?? const Uuid().v4(),
      mixId: _selectedMix!.id,
      mixName: _selectedMix!.name,
      productName: mergedOutputs.isNotEmpty
          ? mergedOutputs.map((o) => o.productName).join(', ')
          : _selectedMix!.productName,
      inputKg: inputKg,
      outputKg: totalOutput > 0 ? totalOutput : null,
      outputs: mergedOutputs,
      damagedKg: _damagedKg > 0 ? _damagedKg : null,
      technicianCost: double.tryParse(_techCtrl.text) ?? 0,
      electricityCost: double.tryParse(_elecCtrl.text) ?? 0,
      additionalCosts: _additionalCosts,
      customFields: _customFields,
      rawMaterialCost: _rawMaterialCost,
      totalCost: _totalCost,
      costPerKg: _costPerKg,
      status: widget.editing?.status ?? ProductionRunStatus.draft,
      notes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
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
          ? l10n.mfgAddRun
          : l10n.mfgEditRun),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              DropdownButtonFormField<ManufacturingMixModel>(
                value: _selectedMix,
                decoration:
                    InputDecoration(labelText: l10n.mfgMixLabel),
                items: _mixes
                    .map((m) => DropdownMenuItem(
                        value: m, child: Text(m.name)))
                    .toList(),
                onChanged: _isExecuted
                    ? null
                    : (v) {
                        setState(() => _selectedMix = v);
                        _recalculate();
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _inputCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration:
                    InputDecoration(labelText: l10n.mfgInputQty),
                onChanged: (_) => _recalculate(),
                readOnly: _isExecuted,
              ),
              const SizedBox(height: 12),
              BlocBuilder<ProductBloc, ProductState>(
                builder: (context, productState) {
                  final products = productState is ProductLoaded
                      ? productState.products
                          .where((p) => p.isActive)
                          .toList()
                      : <ProductModel>[];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(l10n.mfgOutputProducts,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (!_isExecuted && products.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                final product = products.first;
                                setState(() {
                                  _outputs.add(ProductionRunOutput(
                                    productId: product.id,
                                    productName: product.name,
                                    quantityKg: 0,
                                  ));
                                });
                                _recalculate();
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(l10n.mfgAddOutputProduct),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (products.isEmpty)
                        Text(l10n.mfgNoProductsAvailable,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13))
                      else
                        ..._outputs.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final output = entry.value;
                          return _OutputProductRow(
                            output: output,
                            products: products,
                            readOnly: _isExecuted,
                            onChanged: (updated) {
                              setState(() => _outputs[idx] = updated);
                              _recalculate();
                            },
                            onRemove: _isExecuted
                                ? null
                                : () {
                                    setState(() => _outputs.removeAt(idx));
                                    _recalculate();
                                  },
                          );
                        }),
                      if (_totalOutputKg > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.infoColor
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${l10n.mfgTotalOutputQty}: ${_totalOutputKg.toStringAsFixed(1)} ${l10n.mfgKg}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.infoColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              // Auto-calculated damaged display
              if (_inputKg > 0 && _totalOutputKg > 0)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.warningColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          size: 18, color: AppTheme.warningColor),
                      const SizedBox(width: 8),
                      Text(
                        '${l10n.mfgDamagedLabel}: ${_damagedKg.toStringAsFixed(1)} ${l10n.mfgKg}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warningColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '(${l10n.mfgInputLabel} - ${l10n.mfgOutputLabel})',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
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
                    readOnly: _isExecuted,
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
                    readOnly: _isExecuted,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // Custom fields section
              _buildCustomFieldsSection(l10n),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                        '${l10n.date}: ${DateFormat('dd/MM/yyyy').format(_date)}'),
                  ),
                  if (!_isExecuted)
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
                readOnly: _isExecuted,
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
        if (!_isExecuted)
          ElevatedButton(
            onPressed: () {
              if (_selectedMix == null) return;
              if (_inputKg <= 0) return;
              widget.onSave(_buildRun());
              Navigator.pop(context);
            },
            child:
                Text(widget.editing == null ? l10n.mfgAddRun : l10n.mfgSave),
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


  Widget _buildCustomFieldsSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.mfgCustomFields,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (!_isExecuted)
              TextButton.icon(
                onPressed: _addCustomField,
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n.add),
              ),
          ],
        ),
        ..._customFields.asMap().entries.map((entry) {
          final i = entry.key;
          final f = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(f.label,
                      style: const TextStyle(fontSize: 13)),
                ),
                Expanded(
                  child: Text(
                    '\$${f.value.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (!_isExecuted)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() => _customFields.removeAt(i));
                      _recalculate();
                    },
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _addCustomField() {
    final labelCtrl = TextEditingController();
    final valueCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.mfgAddCustomField),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(labelText: l10n.mfgFieldLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.mfgFieldValue),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () {
                final label = labelCtrl.text.trim();
                final value = double.tryParse(valueCtrl.text) ?? 0;
                if (label.isEmpty || value <= 0) return;
                setState(() {
                  _customFields.add(CustomRunField(
                    label: label,
                    value: value,
                  ));
                });
                _recalculate();
                Navigator.pop(ctx);
              },
              child: Text(l10n.add),
            ),
          ],
        );
      },
    );
  }
}

class _OutputProductRow extends StatefulWidget {
  final ProductionRunOutput output;
  final List<ProductModel> products;
  final bool readOnly;
  final ValueChanged<ProductionRunOutput> onChanged;
  final VoidCallback? onRemove;

  const _OutputProductRow({
    required this.output,
    required this.products,
    required this.readOnly,
    required this.onChanged,
    this.onRemove,
  });

  @override
  State<_OutputProductRow> createState() => _OutputProductRowState();
}

class _OutputProductRowState extends State<_OutputProductRow> {
  late final TextEditingController _qtyCtrl;
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.output.quantityKg > 0
          ? widget.output.quantityKg.toString()
          : '',
    );
    _selectedId = widget.output.productId.isNotEmpty &&
            widget.products.any((p) => p.id == widget.output.productId)
        ? widget.output.productId
        : (widget.products.isNotEmpty ? widget.products.first.id : '');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: _selectedId.isEmpty ? null : _selectedId,
              decoration:
                  InputDecoration(labelText: l10n.mfgSelectProduct),
              items: widget.products
                  .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} (${p.size})'),
                      ))
                  .toList(),
              onChanged: widget.readOnly
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => _selectedId = v);
                      final product =
                          widget.products.firstWhere((p) => p.id == v);
                      widget.onChanged(widget.output.copyWith(
                        productId: v,
                        productName: product.name,
                      ));
                    },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _qtyCtrl,
              readOnly: widget.readOnly,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: l10n.mfgOutputProductQty),
              onChanged: (v) {
                widget.onChanged(widget.output.copyWith(
                  quantityKg: double.tryParse(v) ?? 0,
                ));
              },
            ),
          ),
          if (widget.onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onRemove,
            ),
        ],
      ),
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
