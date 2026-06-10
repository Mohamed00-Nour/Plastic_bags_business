import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum MaterialStockChangeType { addition, reduction }

class MaterialStockLogModel extends Equatable {
  final String id;
  final String materialId;
  final String materialName;
  final MaterialStockChangeType type;
  final double quantityKg;
  final double stockBefore;
  final double stockAfter;
  final String? note;
  final String createdBy;
  final DateTime createdAt;

  const MaterialStockLogModel({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.type,
    required this.quantityKg,
    required this.stockBefore,
    required this.stockAfter,
    this.note,
    this.createdBy = '',
    required this.createdAt,
  });

  factory MaterialStockLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MaterialStockLogModel(
      id: doc.id,
      materialId: data['materialId'] ?? '',
      materialName: data['materialName'] ?? '',
      type: data['type'] == 'addition'
          ? MaterialStockChangeType.addition
          : MaterialStockChangeType.reduction,
      quantityKg: (data['quantityKg'] ?? 0).toDouble(),
      stockBefore: (data['stockBefore'] ?? 0).toDouble(),
      stockAfter: (data['stockAfter'] ?? 0).toDouble(),
      note: data['note'],
      createdBy: data['createdBy'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'materialId': materialId,
        'materialName': materialName,
        'type': type == MaterialStockChangeType.addition
            ? 'addition'
            : 'reduction',
        'quantityKg': quantityKg,
        'stockBefore': stockBefore,
        'stockAfter': stockAfter,
        'note': note,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  @override
  List<Object?> get props =>
      [id, materialId, type, quantityKg, createdAt];
}
