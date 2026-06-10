import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ManufacturingExpenseModel extends Equatable {
  final String id;
  final String category;
  final double amount;
  final DateTime date;
  final String? description;
  final String? productionRunId;
  final bool includeInCostPerKg;
  final String createdBy;
  final String modifiedBy;
  final DateTime createdAt;

  const ManufacturingExpenseModel({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    this.description,
    this.productionRunId,
    this.includeInCostPerKg = false,
    required this.createdBy,
    this.modifiedBy = '',
    required this.createdAt,
  });

  factory ManufacturingExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ManufacturingExpenseModel(
      id: doc.id,
      category: data['category'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'],
      productionRunId: data['productionRunId'],
      includeInCostPerKg: data['includeInCostPerKg'] ?? false,
      createdBy: data['createdBy'] ?? '',
      modifiedBy: data['modifiedBy'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'category': category,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'description': description,
        'productionRunId': productionRunId,
        'includeInCostPerKg': includeInCostPerKg,
        'createdBy': createdBy,
        'modifiedBy': modifiedBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  ManufacturingExpenseModel copyWith({
    String? id,
    String? category,
    double? amount,
    DateTime? date,
    String? description,
    String? productionRunId,
    bool? includeInCostPerKg,
    String? createdBy,
    String? modifiedBy,
    DateTime? createdAt,
  }) {
    return ManufacturingExpenseModel(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      productionRunId: productionRunId ?? this.productionRunId,
      includeInCostPerKg: includeInCostPerKg ?? this.includeInCostPerKg,
      createdBy: createdBy ?? this.createdBy,
      modifiedBy: modifiedBy ?? this.modifiedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, category, amount, date, productionRunId, includeInCostPerKg];
}
