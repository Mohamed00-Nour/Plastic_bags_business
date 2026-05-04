import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ProductModel extends Equatable {
  final String id;
  final String name;
  final String size;
  final double price;
  final double costPrice;
  final int stockQuantity;
  final String? supplierId;
  final String? supplierName;
  final int lowStockThreshold;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.name,
    required this.size,
    required this.price,
    required this.costPrice,
    this.stockQuantity = 0,
    this.supplierId,
    this.supplierName,
    this.lowStockThreshold = 10,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => stockQuantity <= lowStockThreshold;
  double get profit => price - costPrice;

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      size: data['size'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      costPrice: (data['costPrice'] ?? 0).toDouble(),
      stockQuantity: (data['stockQuantity'] ?? 0).toInt(),
      supplierId: data['supplierId'],
      supplierName: data['supplierName'],
      lowStockThreshold: (data['lowStockThreshold'] ?? 10).toInt(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'size': size,
        'price': price,
        'costPrice': costPrice,
        'stockQuantity': stockQuantity,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'lowStockThreshold': lowStockThreshold,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  ProductModel copyWith({
    String? id,
    String? name,
    String? size,
    double? price,
    double? costPrice,
    int? stockQuantity,
    String? supplierId,
    String? supplierName,
    int? lowStockThreshold,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        size,
        price,
        costPrice,
        stockQuantity,
        supplierId,
        lowStockThreshold,
        isActive,
      ];
}
