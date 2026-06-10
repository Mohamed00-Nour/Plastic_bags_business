import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class DamagedInventoryModel extends Equatable {
  final String id;
  final String productionRunId;
  final String mixId;
  final String mixName;
  final String productName;
  final double damagedKg;
  final DateTime date;
  final String createdBy;
  final DateTime createdAt;

  const DamagedInventoryModel({
    required this.id,
    required this.productionRunId,
    required this.mixId,
    required this.mixName,
    required this.productName,
    required this.damagedKg,
    required this.date,
    this.createdBy = '',
    required this.createdAt,
  });

  factory DamagedInventoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DamagedInventoryModel(
      id: doc.id,
      productionRunId: data['productionRunId'] ?? '',
      mixId: data['mixId'] ?? '',
      mixName: data['mixName'] ?? '',
      productName: data['productName'] ?? '',
      damagedKg: (data['damagedKg'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'productionRunId': productionRunId,
        'mixId': mixId,
        'mixName': mixName,
        'productName': productName,
        'damagedKg': damagedKg,
        'date': Timestamp.fromDate(date),
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  @override
  List<Object?> get props =>
      [id, productionRunId, damagedKg, date];
}
