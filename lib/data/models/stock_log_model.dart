import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum StockMovementType { incoming, outgoing, adjustment }

extension StockMovementTypeX on StockMovementType {
  String get label {
    switch (this) {
      case StockMovementType.incoming:
        return 'Incoming';
      case StockMovementType.outgoing:
        return 'Outgoing';
      case StockMovementType.adjustment:
        return 'Adjustment';
    }
  }
}

class StockLogModel extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final StockMovementType type;
  final int quantity;
  final int stockBefore;
  final int stockAfter;
  final String? referenceId;
  final String? note;
  final String? supplierId;
  final String? supplierName;
  final double? unitCost;
  final double? avgCostAfter;
  final String createdBy;
  final DateTime createdAt;

  const StockLogModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    this.referenceId,
    this.note,
    this.supplierId,
    this.supplierName,
    this.unitCost,
    this.avgCostAfter,
    required this.createdBy,
    required this.createdAt,
  });

  factory StockLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockLogModel(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      type: StockMovementType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => StockMovementType.adjustment,
      ),
      quantity: (data['quantity'] ?? 0).toInt(),
      stockBefore: (data['stockBefore'] ?? 0).toInt(),
      stockAfter: (data['stockAfter'] ?? 0).toInt(),
      referenceId: data['referenceId'],
      note: data['note'],
      supplierId: data['supplierId'],
      supplierName: data['supplierName'],
      unitCost: data['unitCost'] != null
          ? (data['unitCost'] as num).toDouble()
          : null,
      avgCostAfter: data['avgCostAfter'] != null
          ? (data['avgCostAfter'] as num).toDouble()
          : null,
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'productId': productId,
        'productName': productName,
        'type': type.name,
        'quantity': quantity,
        'stockBefore': stockBefore,
        'stockAfter': stockAfter,
        'referenceId': referenceId,
        'note': note,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'unitCost': unitCost,
        'avgCostAfter': avgCostAfter,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        type,
        quantity,
        stockBefore,
        stockAfter,
        referenceId,
        note,
        supplierId,
        supplierName,
        unitCost,
        avgCostAfter,
        createdBy,
        createdAt,
      ];
}
