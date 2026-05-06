import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_state.dart';

class ShopTransactionsScreen extends StatelessWidget {
  const ShopTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated || state.user.shopId == null) {
          return Center(child: Text(l10n.noShopAssigned));
        }
        final shopId = state.user.shopId!;
        final dateFormat = DateFormat('MMM dd, yyyy');
        final numFmt = NumberFormat('#,##0.0');

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('transactions')
              .where('shopId', isEqualTo: shopId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final transactions = snapshot.data!.docs;
            if (transactions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(l10n.noTransactionsYet,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5))),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final data =
                    transactions[index].data() as Map<String, dynamic>;
                final type = data['type'] ?? '';
                final amount = (data['amount'] ?? 0).toDouble();
                final createdAt =
                    (data['createdAt'] as Timestamp?)?.toDate();

                final isCredit =
                    type == 'balanceCharge' || type == 'refund';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCredit
                            ? AppTheme.successColor
                            : Colors.orange,
                        child: Icon(
                          isCredit
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        _typeLabel(type, l10n),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        createdAt != null ? dateFormat.format(createdAt) : '',
                      ),
                      trailing: Text(
                        '${isCredit ? '+' : '-'}${numFmt.format(amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isCredit
                              ? AppTheme.successColor
                              : AppTheme.dangerColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _typeLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'balanceCharge':
        return l10n.transactionBalanceCharge;
      case 'purchase':
        return l10n.transactionPurchase;
      case 'refund':
        return l10n.transactionRefund;
      case 'supplierPayment':
        return l10n.transactionSupplierPayment;
      default:
        return type;
    }
  }
}
