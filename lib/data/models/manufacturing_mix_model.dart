import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class MixComponent extends Equatable {
  final String materialId;
  final String materialName;
  final double quantityKg;

  const MixComponent({
    required this.materialId,
    required this.materialName,
    required this.quantityKg,
  });

  factory MixComponent.fromMap(Map<String, dynamic> map) {
    return MixComponent(
      materialId: map['materialId'] ?? '',
      materialName: map['materialName'] ?? '',
      quantityKg: (map['quantityKg'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'materialId': materialId,
        'materialName': materialName,
        'quantityKg': quantityKg,
      };

  MixComponent copyWith({
    String? materialId,
    String? materialName,
    double? quantityKg,
  }) {
    return MixComponent(
      materialId: materialId ?? this.materialId,
      materialName: materialName ?? this.materialName,
      quantityKg: quantityKg ?? this.quantityKg,
    );
  }

  @override
  List<Object?> get props => [materialId, materialName, quantityKg];
}

class ManufacturingMixModel extends Equatable {
  final String id;
  final String name;
  final String productName;
  final List<MixComponent> components;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ManufacturingMixModel({
    required this.id,
    required this.name,
    required this.productName,
    required this.components,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalQuantityKg =>
      components.fold(0, (s, c) => s + c.quantityKg);

  factory ManufacturingMixModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawComponents = data['components'] as List<dynamic>? ?? [];
    return ManufacturingMixModel(
      id: doc.id,
      name: data['name'] ?? '',
      productName: data['productName'] ?? '',
      components: rawComponents
          .map((c) => MixComponent.fromMap(c as Map<String, dynamic>))
          .toList(),
      isActive: data['isActive'] ?? true,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'productName': productName,
        'components': components.map((c) => c.toMap()).toList(),
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  ManufacturingMixModel copyWith({
    String? id,
    String? name,
    String? productName,
    List<MixComponent>? components,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ManufacturingMixModel(
      id: id ?? this.id,
      name: name ?? this.name,
      productName: productName ?? this.productName,
      components: components ?? this.components,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, productName, isActive];
}
