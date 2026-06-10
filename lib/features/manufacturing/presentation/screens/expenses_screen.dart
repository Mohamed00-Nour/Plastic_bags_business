import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/current_user_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/manufacturing_expense_model.dart';
import '../../bloc/manufacturing_expense_bloc.dart';
import '../../bloc/manufacturing_expense_event.dart';
import '../../bloc/manufacturing_expense_state.dart';

const _kCategories = [
  'كهرباء',
  'صيانة',
  'نقل',
  'رواتب',
  'مواد تشغيل',
  'إيجار',
  'متنوعات',
];

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? _filterCategory;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ManufacturingExpenseBloc, ManufacturingExpenseState>(
      listener: (context, state) {
        if (state is ManufacturingExpenseOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppTheme.successColor,
          ));
          context
              .read<ManufacturingExpenseBloc>()
              .add(ManufacturingExpenseLoadRequested());
        } else if (state is ManufacturingExpenseError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppTheme.dangerColor,
          ));
        }
      },
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final loaded = state is ManufacturingExpenseLoaded ? state : null;
        final displayExpenses = loaded != null
            ? (_filterCategory != null
                ? loaded.expenses
                    .where((e) => e.category == _filterCategory)
                    .toList()
                : loaded.expenses)
            : <ManufacturingExpenseModel>[];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Summary row
              if (loaded != null) _buildSummary(context, loaded),
              const SizedBox(height: 12),
              // Filter + Add
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _filterCategory,
                      decoration:
                          InputDecoration(labelText: l10n.mfgFilterByCategory),
                      items: [
                        DropdownMenuItem(
                            value: null, child: Text(l10n.mfgAll)),
                        ..._kCategories.map((c) =>
                            DropdownMenuItem(value: c, child: Text(c))),
                      ],
                      onChanged: (v) =>
                          setState(() => _filterCategory = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showForm(context, null),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.mfgAddExpense),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // List
              Expanded(
                child: state is ManufacturingExpenseLoading
                    ? const Center(child: CircularProgressIndicator())
                    : displayExpenses.isEmpty
                        ? Center(child: Text(l10n.mfgNoExpenses))
                        : ListView.builder(
                            itemCount: displayExpenses.length,
                            itemBuilder: (_, i) {
                              final e = displayExpenses[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.warningColor
                                        .withValues(alpha: 0.12),
                                    child: const Icon(
                                        Icons.receipt_long_outlined,
                                        color: AppTheme.warningColor),
                                  ),
                                  title: Text(e.category,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Builder(builder: (bCtx) {
                                    final l10n = AppLocalizations.of(bCtx)!;
                                    return Text(
                                      '${DateFormat('dd/MM/yyyy').format(e.date)}'
                                      '${e.description != null ? ' | ${e.description}' : ''}'
                                      '${e.productionRunId != null ? ' | ${l10n.mfgLinkedToRun}' : ''}',
                                    );
                                  }),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '\$${e.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: AppTheme.dangerColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (e.includeInCostPerKg)
                                        Builder(builder: (bCtx) {
                                          final l10n = AppLocalizations.of(bCtx)!;
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.infoColor
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(l10n.mfgIncludesInCostLabel,
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppTheme.infoColor)),
                                          );
                                        }),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () =>
                                            _showForm(context, e),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: AppTheme.dangerColor),
                                        onPressed: () =>
                                            _confirmDelete(context, e),
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
      },
    );
  }

  Widget _buildSummary(BuildContext context, ManufacturingExpenseLoaded state) {
    final l10n = AppLocalizations.of(context)!;
    final byCategory = state.totalByCategory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.dangerColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.summarize_outlined,
                  color: AppTheme.dangerColor),
              const SizedBox(width: 8),
              Text(
                '${l10n.mfgGrandTotal}: \$${state.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.dangerColor,
                    fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: byCategory.entries.map((e) {
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${e.key}: \$${e.value.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.warningColor),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  void _showForm(BuildContext context, ManufacturingExpenseModel? editing) {
    final l10n = AppLocalizations.of(context)!;
    String selectedCategory = editing?.category ?? _kCategories.first;
    final amountCtrl = TextEditingController(
        text: editing != null ? editing.amount.toString() : '');
    final descCtrl =
        TextEditingController(text: editing?.description ?? '');
    bool includeInCost = editing?.includeInCostPerKg ?? false;
    DateTime date = editing?.date ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(editing == null ? l10n.mfgAddExpense : l10n.mfgEditExpense),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration:
                      InputDecoration(labelText: l10n.mfgCategoryLabel),
                  items: _kCategories
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setDlg(() => selectedCategory = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: l10n.mfgAmountLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.mfgDescriptionOptional),
                ),
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
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(l10n.mfgChooseDate),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.mfgIncludeInCostPerKg),
                  value: includeInCost,
                  onChanged: (v) =>
                      setDlg(() => includeInCost = v),
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
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) return;
                final now = DateTime.now();
                final expense = ManufacturingExpenseModel(
                  id: editing?.id ?? const Uuid().v4(),
                  category: selectedCategory,
                  amount: amount,
                  date: date,
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  includeInCostPerKg: includeInCost,
                  createdBy: CurrentUserService.instance.userName,
                  createdAt: editing?.createdAt ?? now,
                );
                if (editing == null) {
                  context.read<ManufacturingExpenseBloc>().add(
                      ManufacturingExpenseAddRequested(expense: expense));
                } else {
                  context.read<ManufacturingExpenseBloc>().add(
                      ManufacturingExpenseUpdateRequested(expense: expense));
                }
                Navigator.pop(ctx);
              },
              child: Text(editing == null ? l10n.mfgAddExpense : l10n.mfgSave),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, ManufacturingExpenseModel e) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mfgConfirmDelete),
        content: Text(l10n.mfgDeleteConfirm(e.category)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor),
            onPressed: () {
              context
                  .read<ManufacturingExpenseBloc>()
                  .add(ManufacturingExpenseDeleteRequested(id: e.id));
              Navigator.pop(ctx);
            },
            child: Text(l10n.mfgDelete),
          ),
        ],
      ),
    );
  }
}
