import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum TransactionType { balanceCharge, purchase, refund, supplierPayment }

extension TransactionTypeX on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.balanceCharge:
        return 'Balance Charge';
      case TransactionType.purchase:
        return 'Purchase';
      case TransactionType.refund:
        return 'Refund';
      case TransactionType.supplierPayment:
        return 'Supplier Payment';
    }
  }
}

class TransactionModel extends Equatable {
  final String id;
  final String? shopId;
  final String? shopName;
  final String? supplierId;
  final String? supplierName;
  final TransactionType type;
  final double amount;
  final double balanceAfter;
  final String? orderId;
  final String? description;
  final String createdBy;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    this.shopId,
    this.shopName,
    this.supplierId,
    this.supplierName,
    required this.type,
    required this.amount,
    this.balanceAfter = 0,
    this.orderId,
    this.description,
    required this.createdBy,
    required this.createdAt,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      shopId: data['shopId'],
      shopName: data['shopName'],
      supplierId: data['supplierId'],
      supplierName: data['supplierName'],
      type: TransactionType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => TransactionType.purchase,
      ),
      amount: (data['amount'] ?? 0).toDouble(),
      balanceAfter: (data['balanceAfter'] ?? 0).toDouble(),
      orderId: data['orderId'],
      description: data['description'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'shopId': shopId,
        'shopName': shopName,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'type': type.name,
        'amount': amount,
        'balanceAfter': balanceAfter,
        'orderId': orderId,
        'description': description,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  @override
  List<Object?> get props => [id, shopId, supplierId, type, amount, createdAt];
}
