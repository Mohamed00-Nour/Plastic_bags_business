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
  final double stockQuantity;
  final String? supplierId;
  final String? supplierName;
  final double lowStockThreshold;
  final int sortOrder;
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
    this.stockQuantity = 0.0,
    this.supplierId,
    this.supplierName,
    this.lowStockThreshold = 10.0,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdBy = '',
    this.modifiedBy = '',
    required this.createdAt,
    required this.updatedAt,
  }) : price1 = price1 ?? price;

  bool get isLowStock => stockQuantity <= lowStockThreshold;
  double get profit => price - costPrice;

  static double _toDouble(dynamic val, [double defaultVal = 0.0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? defaultVal;
    return defaultVal;
  }

  static double? _toNullableDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  static int _toInt(dynamic val, [int defaultVal = 0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? defaultVal;
    return defaultVal;
  }

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final double defaultPrice = _toDouble(data['price']);
    return ProductModel(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      size: data['size']?.toString() ?? '',
      price: defaultPrice,
      costPrice: _toDouble(data['costPrice']),
      price1: data['price1'] != null ? _toDouble(data['price1'], defaultPrice) : defaultPrice,
      price2: _toNullableDouble(data['price2']),
      price3: _toNullableDouble(data['price3']),
      stockQuantity: _toDouble(data['stockQuantity']),
      supplierId: data['supplierId']?.toString(),
      supplierName: data['supplierName']?.toString(),
      lowStockThreshold: _toDouble(data['lowStockThreshold'], 10.0),
      sortOrder: _toInt(data['sortOrder'] ?? data['order'], 0),
      isActive: data['isActive'] as bool? ?? true,
      createdBy: data['createdBy']?.toString() ?? '',
      modifiedBy: data['modifiedBy']?.toString() ?? '',
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
    'sortOrder': sortOrder,
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
    double? stockQuantity,
    String? supplierId,
    String? supplierName,
    double? lowStockThreshold,
    int? sortOrder,
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
      sortOrder: sortOrder ?? this.sortOrder,
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
    sortOrder,
    isActive,
  ];
}
