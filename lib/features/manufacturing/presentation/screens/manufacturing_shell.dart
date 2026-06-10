import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../bloc/raw_material_bloc.dart';
import '../../bloc/raw_material_event.dart';
import '../../bloc/manufacturing_mix_bloc.dart';
import '../../bloc/manufacturing_mix_event.dart';
import '../../bloc/production_run_bloc.dart';
import '../../bloc/production_run_event.dart';
import '../../bloc/waste_processing_bloc.dart';
import '../../bloc/waste_processing_event.dart';
import '../../bloc/manufacturing_expense_bloc.dart';
import '../../bloc/manufacturing_expense_event.dart';
import '../../bloc/manufacturing_expense_state.dart';
import '../../bloc/production_run_state.dart';
import '../../bloc/waste_processing_state.dart';
import '../../bloc/material_supplier_bloc.dart';
import '../../bloc/material_supplier_event.dart';
import 'raw_materials_screen.dart';
import 'mixes_screen.dart';
import 'production_runs_screen.dart';
import 'waste_processing_screen.dart';
import 'expenses_screen.dart';
import 'material_suppliers_screen.dart';
import 'damaged_inventory_screen.dart';

class ManufacturingShell extends StatefulWidget {
  const ManufacturingShell({super.key});

  @override
  State<ManufacturingShell> createState() => _ManufacturingShellState();
}

class _ManufacturingShellState extends State<ManufacturingShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    context.read<RawMaterialBloc>().add(RawMaterialLoadRequested());
    context
        .read<ManufacturingMixBloc>()
        .add(ManufacturingMixLoadRequested());
    context
        .read<ProductionRunBloc>()
        .add(ProductionRunLoadRequested());
    context
        .read<WasteProcessingBloc>()
        .add(WasteProcessingLoadRequested());
    context
        .read<ManufacturingExpenseBloc>()
        .add(ManufacturingExpenseLoadRequested());
    context
        .read<MaterialSupplierBloc>()
        .add(MaterialSupplierLoadRequested());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildSummaryBanner(context, l10n),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: const Icon(Icons.science_outlined), text: l10n.mfgRawMaterialsTab),
            Tab(icon: const Icon(Icons.blender_outlined), text: l10n.mfgMixesTab),
            Tab(icon: const Icon(Icons.precision_manufacturing_outlined), text: l10n.mfgProductionTab),
            Tab(icon: const Icon(Icons.recycling_outlined), text: l10n.mfgWasteTab),
            Tab(icon: const Icon(Icons.receipt_long_outlined), text: l10n.mfgExpensesTab),
            Tab(icon: const Icon(Icons.local_shipping_outlined), text: l10n.mfgMaterialSuppliersTab),
            Tab(icon: const Icon(Icons.broken_image_outlined), text: l10n.mfgDamagedInventoryTab),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              RawMaterialsScreen(),
              MixesScreen(),
              ProductionRunsScreen(),
              WasteProcessingScreen(),
              ExpensesScreen(),
              MaterialSuppliersScreen(),
              DamagedInventoryScreen(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBanner(BuildContext context, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.factory_outlined,
              color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            l10n.manufacturing,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          BlocBuilder<ProductionRunBloc, ProductionRunState>(
            builder: (ctx, state) {
              final l10n = AppLocalizations.of(ctx)!;
              final runs =
                  state is ProductionRunLoaded ? state.runs.length : 0;
              return _SummaryChip(
                  label: l10n.mfgRunsChip, value: '$runs', color: AppTheme.infoColor);
            },
          ),
          const SizedBox(width: 8),
          BlocBuilder<ManufacturingExpenseBloc, ManufacturingExpenseState>(
            builder: (ctx, state) {
              final l10n = AppLocalizations.of(ctx)!;
              final total = state is ManufacturingExpenseLoaded
                  ? state.grandTotal
                  : 0.0;
              return _SummaryChip(
                label: l10n.mfgExpensesChip,
                value: '\$${total.toStringAsFixed(0)}',
                color: AppTheme.warningColor,
              );
            },
          ),
          const SizedBox(width: 8),
          BlocBuilder<WasteProcessingBloc, WasteProcessingState>(
            builder: (ctx, state) {
              final l10n = AppLocalizations.of(ctx)!;
              final runs =
                  state is WasteProcessingLoaded ? state.runs.length : 0;
              return _SummaryChip(
                  label: l10n.mfgWasteChip,
                  value: '$runs',
                  color: AppTheme.successColor);
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
