import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class RawMaterialModel extends Equatable {
  final String id;
  final String name;
  final String type;
  final double pricePerKg;
  final String unit;
  final double quantityKg;
  final double lowStockThreshold;
  final String? supplierId;
  final String? supplierName;
  final bool isActive;
  final String createdBy;
  final String modifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RawMaterialModel({
    required this.id,
    required this.name,
    required this.type,
    required this.pricePerKg,
    this.unit = 'kg',
    this.quantityKg = 0,
    this.lowStockThreshold = 0,
    this.supplierId,
    this.supplierName,
    this.isActive = true,
    this.createdBy = '',
    this.modifiedBy = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock =>
      lowStockThreshold > 0 && quantityKg <= lowStockThreshold;

  factory RawMaterialModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RawMaterialModel(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      pricePerKg: (data['pricePerKg'] ?? 0).toDouble(),
      unit: data['unit'] ?? 'kg',
      quantityKg: (data['quantityKg'] ?? 0).toDouble(),
      lowStockThreshold: (data['lowStockThreshold'] ?? 0).toDouble(),
      supplierId: data['supplierId'],
      supplierName: data['supplierName'],
      isActive: data['isActive'] ?? true,
      createdBy: data['createdBy'] ?? '',
      modifiedBy: data['modifiedBy'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'type': type,
        'pricePerKg': pricePerKg,
        'unit': unit,
        'quantityKg': quantityKg,
        'lowStockThreshold': lowStockThreshold,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'isActive': isActive,
        'createdBy': createdBy,
        'modifiedBy': modifiedBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  RawMaterialModel copyWith({
    String? id,
    String? name,
    String? type,
    double? pricePerKg,
    String? unit,
    double? quantityKg,
    double? lowStockThreshold,
    String? supplierId,
    String? supplierName,
    bool? isActive,
    String? createdBy,
    String? modifiedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RawMaterialModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      unit: unit ?? this.unit,
      quantityKg: quantityKg ?? this.quantityKg,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      modifiedBy: modifiedBy ?? this.modifiedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, type, pricePerKg, unit, quantityKg, supplierId, isActive];
}
