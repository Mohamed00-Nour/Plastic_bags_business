import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ShopModel extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final double totalPurchases;
  final bool isActive;
  final String? loginEmail;
  final String? loginPassword;
  final String createdBy;
  final String modifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShopModel({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.totalPurchases = 0,
    this.isActive = true,
    this.loginEmail,
    this.loginPassword,
    this.createdBy = '',
    this.modifiedBy = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShopModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShopModel(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'],
      totalPurchases: (data['totalPurchases'] ?? 0).toDouble(),
      isActive: data['isActive'] ?? true,
      loginEmail: data['loginEmail'],
      loginPassword: data['loginPassword'],
      createdBy: data['createdBy'] ?? '',
      modifiedBy: data['modifiedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'phone': phone,
        'address': address,
        'totalPurchases': totalPurchases,
        'isActive': isActive,
        'loginEmail': loginEmail,
        'loginPassword': loginPassword,
        'createdBy': createdBy,
        'modifiedBy': modifiedBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  ShopModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    double? totalPurchases,
    bool? isActive,
    String? loginEmail,
    String? loginPassword,
    String? createdBy,
    String? modifiedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      isActive: isActive ?? this.isActive,
      loginEmail: loginEmail ?? this.loginEmail,
      loginPassword: loginPassword ?? this.loginPassword,
      createdBy: createdBy ?? this.createdBy,
      modifiedBy: modifiedBy ?? this.modifiedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, phone, address, totalPurchases, isActive, loginEmail, loginPassword];
}
