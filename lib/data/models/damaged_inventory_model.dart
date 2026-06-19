import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum DamagedInventoryEntryType { addition, deduction }

class DamagedInventoryModel extends Equatable {
  final String id;
  final String productionRunId;
  final String? wasteRunId;
  final String mixId;
  final String mixName;
  final String productName;
  final double damagedKg;
  final DamagedInventoryEntryType entryType;
  final DateTime date;
  final String createdBy;
  final DateTime createdAt;

  const DamagedInventoryModel({
    required this.id,
    this.productionRunId = '',
    this.wasteRunId,
    this.mixId = '',
    required this.mixName,
    required this.productName,
    required this.damagedKg,
    this.entryType = DamagedInventoryEntryType.addition,
    required this.date,
    this.createdBy = '',
    required this.createdAt,
  });

  double get signedKg =>
      entryType == DamagedInventoryEntryType.deduction
          ? -damagedKg
          : damagedKg;

  bool get isDeduction =>
      entryType == DamagedInventoryEntryType.deduction;

  factory DamagedInventoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DamagedInventoryModel(
      id: doc.id,
      productionRunId: data['productionRunId'] ?? '',
      wasteRunId: data['wasteRunId'],
      mixId: data['mixId'] ?? '',
      mixName: data['mixName'] ?? '',
      productName: data['productName'] ?? '',
      damagedKg: (data['damagedKg'] ?? 0).toDouble(),
      entryType: data['entryType'] == 'deduction'
          ? DamagedInventoryEntryType.deduction
          : DamagedInventoryEntryType.addition,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'productionRunId': productionRunId,
        'wasteRunId': wasteRunId,
        'mixId': mixId,
        'mixName': mixName,
        'productName': productName,
        'damagedKg': damagedKg,
        'entryType':
            entryType == DamagedInventoryEntryType.deduction
                ? 'deduction'
                : 'addition',
        'date': Timestamp.fromDate(date),
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  @override
  List<Object?> get props =>
      [id, productionRunId, wasteRunId, damagedKg, entryType, date];
}
