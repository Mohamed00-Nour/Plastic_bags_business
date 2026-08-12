import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ProductModel extends Equatable {
  final String id;
  final String name;
  final String size;
  final double price; // Default selling price (Price 1)
  final double costPrice;
  final double price1; // Selling Price 1
  final double? price2; // Selling Price 2
  final double? price3; // Selling Price 3
  final int stockQuantity;
  final String? supplierId;
  final String? supplierName;
  final int lowStockThreshold;
  final bool isActive;
  final String createdBy;
  final String modifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.name,
    required this.size,
    required this.price,
    required this.costPrice,
    double? price1,
    this.price2,
    this.price3,
    this.stockQuantity = 0,
    this.supplierId,
    this.supplierName,
    this.lowStockThreshold = 10,
    this.isActive = true,
    this.createdBy = '',
    this.modifiedBy = '',
    required this.createdAt,
    required this.updatedAt,
  }) : price1 = price1 ?? price;

  bool get isLowStock => stockQuantity <= lowStockThreshold;
  double get profit => price - costPrice;

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final double defaultPrice = (data['price'] ?? 0).toDouble();
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      size: data['size'] ?? '',
      price: defaultPrice,
      costPrice: (data['costPrice'] ?? 0).toDouble(),
      price1:
          data['price1'] != null
              ? (data['price1'] as num).toDouble()
              : defaultPrice,
      price2:
          data['price2'] != null ? (data['price2'] as num).toDouble() : null,
      price3:
          data['price3'] != null ? (data['price3'] as num).toDouble() : null,
      stockQuantity: (data['stockQuantity'] ?? 0).toInt(),
      supplierId: data['supplierId'],
      supplierName: data['supplierName'],
      lowStockThreshold: (data['lowStockThreshold'] ?? 10).toInt(),
      isActive: data['isActive'] ?? true,
      createdBy: data['createdBy'] ?? '',
      modifiedBy: data['modifiedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'size': size,
    'price': price,
    'costPrice': costPrice,
    'price1': price1,
    'price2': price2,
    'price3': price3,
    'stockQuantity': stockQuantity,
    'supplierId': supplierId,
    'supplierName': supplierName,
    'lowStockThreshold': lowStockThreshold,
    'isActive': isActive,
    'createdBy': createdBy,
    'modifiedBy': modifiedBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  ProductModel copyWith({
    String? id,
    String? name,
    String? size,
    double? price,
    double? costPrice,
    double? price1,
    double? price2,
    double? price3,
    int? stockQuantity,
    String? supplierId,
    String? supplierName,
    int? lowStockThreshold,
    bool? isActive,
    String? createdBy,
    String? modifiedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      price1: price1 ?? this.price1,
      price2: price2 ?? this.price2,
      price3: price3 ?? this.price3,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      modifiedBy: modifiedBy ?? this.modifiedBy,
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
    price1,
    price2,
    price3,
    stockQuantity,
    supplierId,
    lowStockThreshold,
    isActive,
  ];
}
