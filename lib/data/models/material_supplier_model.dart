import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class MaterialSupplierModel extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final bool isActive;
  final String createdBy;
  final String modifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MaterialSupplierModel({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.isActive = true,
    this.createdBy = '',
    this.modifiedBy = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaterialSupplierModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MaterialSupplierModel(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'],
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
        'phone': phone,
        'address': address,
        'isActive': isActive,
        'createdBy': createdBy,
        'modifiedBy': modifiedBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  MaterialSupplierModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    bool? isActive,
    String? createdBy,
    String? modifiedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaterialSupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      modifiedBy: modifiedBy ?? this.modifiedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, phone, address, isActive];
}
