import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
                      hint: 'Search transactions...',
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
                        label: Text(type.label),
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
              Expanded(child: _buildContent(state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(TransactionState state) {
    if (state is TransactionLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is TransactionLoaded) {
      if (state.filteredTransactions.isEmpty) {
        return const EmptyStateWidget(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No transactions found',
        );
      }
      final dateFmt = DateFormat('MMM dd, yyyy HH:mm');
      final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
      return Card(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Shop/Supplier')),
                DataColumn(label: Text('Amount'), numeric: true),
                DataColumn(label: Text('Balance After'), numeric: true),
                DataColumn(label: Text('Description')),
              ],
              rows: state.filteredTransactions.map((t) {
                return DataRow(cells: [
                  DataCell(Text(dateFmt.format(t.createdAt),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(_buildTypeBadge(t.type)),
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
                ]);
              }).toList(),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTypeBadge(TransactionType type) {
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
    return StatusBadge(label: type.label, color: color);
  }
}
