import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SupplierModel extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final double balance;
  final double totalSupplied;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupplierModel({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.balance = 0,
    this.totalSupplied = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplierModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupplierModel(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'],
      balance: (data['balance'] ?? 0).toDouble(),
      totalSupplied: (data['totalSupplied'] ?? 0).toDouble(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'phone': phone,
        'address': address,
        'balance': balance,
        'totalSupplied': totalSupplied,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  SupplierModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    double? balance,
    double? totalSupplied,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      balance: balance ?? this.balance,
      totalSupplied: totalSupplied ?? this.totalSupplied,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, phone, address, balance, totalSupplied, isActive];
}
