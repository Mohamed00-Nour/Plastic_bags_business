import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum OrderStatus { pending, approved, rejected, delivered }

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.approved:
        return 'Approved';
      case OrderStatus.rejected:
        return 'Rejected';
      case OrderStatus.delivered:
        return 'Delivered';
    }
  }
}

class OrderItem extends Equatable {
  final String productId;
  final String productName;
  final String productSize;
  final int quantity;
  final double unitPrice;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.productSize,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productSize: map['productSize'] ?? '',
      quantity: (map['quantity'] ?? 0).toInt(),
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'productSize': productSize,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': total,
      };

  @override
  List<Object?> get props =>
      [productId, productName, productSize, quantity, unitPrice];
}

class OrderModel extends Equatable {
  final String id;
  final String shopId;
  final String shopName;
  final List<OrderItem> items;
  final double totalPrice;
  final OrderStatus status;
  final String? approvedBy;
  final String? rejectionReason;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.items,
    required this.totalPrice,
    this.status = OrderStatus.pending,
    this.approvedBy,
    this.rejectionReason,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      shopName: data['shopName'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => OrderStatus.pending,
      ),
      approvedBy: data['approvedBy'],
      rejectionReason: data['rejectionReason'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'shopId': shopId,
        'shopName': shopName,
        'items': items.map((e) => e.toMap()).toList(),
        'totalPrice': totalPrice,
        'status': status.name,
        'approvedBy': approvedBy,
        'rejectionReason': rejectionReason,
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  OrderModel copyWith({
    String? id,
    String? shopId,
    String? shopName,
    List<OrderItem>? items,
    double? totalPrice,
    OrderStatus? status,
    String? approvedBy,
    String? rejectionReason,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      items: items ?? this.items,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, shopId, shopName, items, totalPrice, status, approvedBy];
}
