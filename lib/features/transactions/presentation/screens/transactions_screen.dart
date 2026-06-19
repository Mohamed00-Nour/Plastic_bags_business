import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/transaction_model.dart';
import '../../bloc/transaction_bloc.dart';
import '../../bloc/transaction_event.dart';
import '../../bloc/transaction_state.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  TransactionType? _selectedFilter;

  @override
  void initState() {
    super.initState();
    context.read<TransactionBloc>().add(TransactionLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SearchField(
                      hint: l10n.searchTransactions,
                      onChanged: (query) => context
                          .read<TransactionBloc>()
                          .add(TransactionSearchRequested(query: query)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ...TransactionType.values.map((type) {
                    final isSelected = _selectedFilter == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(_localizedTransactionType(l10n, type)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = selected ? type : null;
                          });
                          context.read<TransactionBloc>().add(
                              TransactionFilterByType(
                                  type: selected ? type : null));
                        },
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildContent(state, l10n)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(TransactionState state, AppLocalizations l10n) {
    if (state is TransactionLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is TransactionLoaded) {
      if (state.filteredTransactions.isEmpty) {
        return EmptyStateWidget(
          icon: Icons.account_balance_wallet_outlined,
          title: l10n.noTransactionsFound,
        );
      }
      final dateFmt = DateFormat('MMM dd, yyyy HH:mm');
      final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
      return Card(
        child: HorizontalScrollableTable(
          child: SingleChildScrollView(
            child: DataTable(
              columns: [
                DataColumn(label: Text(l10n.date)),
                DataColumn(label: Text(l10n.type)),
                DataColumn(label: Text(l10n.shopSupplier)),
                DataColumn(label: Text(l10n.amount), numeric: true),
                DataColumn(label: Text(l10n.balanceAfter), numeric: true),
                DataColumn(label: Text(l10n.description)),
                DataColumn(label: Text(l10n.createdByLabel)),
              ],
              rows: state.filteredTransactions.map((t) {
                return DataRow(cells: [
                  DataCell(Text(dateFmt.format(t.createdAt),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(_buildTypeBadge(l10n, t.type)),
                  DataCell(Text(t.shopName ?? t.supplierName ?? '-')),
                  DataCell(Text(
                    currFmt.format(t.amount),
                    style: TextStyle(
                      color: t.amount >= 0
                          ? AppTheme.successColor
                          : AppTheme.dangerColor,
                      fontWeight: FontWeight.w600,
                    ),
                  )),
                  DataCell(Text(currFmt.format(t.balanceAfter))),
                  DataCell(Text(t.description ?? '-',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(t.createdBy.isNotEmpty ? t.createdBy : '-')),
                ]);
              }).toList(),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTypeBadge(AppLocalizations l10n, TransactionType type) {
    Color color;
    switch (type) {
      case TransactionType.balanceCharge:
        color = AppTheme.successColor;
        break;
      case TransactionType.purchase:
        color = AppTheme.primaryColor;
        break;
      case TransactionType.refund:
        color = AppTheme.warningColor;
        break;
      case TransactionType.supplierPayment:
        color = AppTheme.infoColor;
        break;
    }
    return StatusBadge(label: _localizedTransactionType(l10n, type), color: color);
  }

  String _localizedTransactionType(AppLocalizations l10n, TransactionType type) {
    switch (type) {
      case TransactionType.balanceCharge:
        return l10n.transactionBalanceCharge;
      case TransactionType.purchase:
        return l10n.transactionPurchase;
      case TransactionType.refund:
        return l10n.transactionRefund;
      case TransactionType.supplierPayment:
        return l10n.transactionSupplierPayment;
    }
  }
}
