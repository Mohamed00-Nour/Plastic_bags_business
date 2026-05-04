import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class RawMaterialModel extends Equatable {
  final String id;
  final String name;
  final String type;
  final double pricePerKg;
  final String unit;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RawMaterialModel({
    required this.id,
    required this.name,
    required this.type,
    required this.pricePerKg,
    this.unit = 'kg',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RawMaterialModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RawMaterialModel(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      pricePerKg: (data['pricePerKg'] ?? 0).toDouble(),
      unit: data['unit'] ?? 'kg',
      isActive: data['isActive'] ?? true,
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
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  RawMaterialModel copyWith({
    String? id,
    String? name,
    String? type,
    double? pricePerKg,
    String? unit,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RawMaterialModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, type, pricePerKg, unit, isActive];
}
