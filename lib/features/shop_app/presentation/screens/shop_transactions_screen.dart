import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_state.dart';

class ShopTransactionsScreen extends StatelessWidget {
  const ShopTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated || state.user.shopId == null) {
          return const Center(child: Text('No shop assigned.'));
        }
        final shopId = state.user.shopId!;
        final dateFormat = DateFormat('MMM dd, yyyy');

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
              return const Center(child: Text('No transactions yet'));
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

                return Card(
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
                      _typeLabel(type),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      createdAt != null ? dateFormat.format(createdAt) : '',
                    ),
                    trailing: Text(
                      '${isCredit ? '+' : '-'}${amount.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isCredit
                            ? AppTheme.successColor
                            : AppTheme.dangerColor,
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

  String _typeLabel(String type) {
    switch (type) {
      case 'balanceCharge':
        return 'Balance Charge';
      case 'purchase':
        return 'Purchase';
      case 'refund':
        return 'Refund';
      case 'supplierPayment':
        return 'Supplier Payment';
      default:
        return type;
    }
  }
}
