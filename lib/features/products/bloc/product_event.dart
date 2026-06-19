import 'package:equatable/equatable.dart';
import '../../../data/models/product_model_new.dart';

abstract class ProductEvent extends Equatable {
  const ProductEvent();
  @override
  List<Object?> get props => [];
}

class ProductLoadRequested extends ProductEvent {}

class ProductAddRequested extends ProductEvent {
  final ProductModel product;
  const ProductAddRequested({required this.product});
  @override
  List<Object?> get props => [product];
}

class ProductUpdateRequested extends ProductEvent {
  final ProductModel product;
  const ProductUpdateRequested({required this.product});
  @override
  List<Object?> get props => [product];
}

class ProductDeleteRequested extends ProductEvent {
  final String productId;
  const ProductDeleteRequested({required this.productId});
  @override
  List<Object?> get props => [productId];
}

class ProductStockIncreased extends ProductEvent {
  final String productId;
  final int amount;
  final double? unitCost;
  final String? note;
  final String? supplierId;
  final String? supplierName;
  
  const ProductStockIncreased({
    required this.productId,
    required this.amount,
    this.unitCost,
    this.note,
    this.supplierId,
    this.supplierName,
  });
  
  @override
  List<Object?> get props =>
      [productId, amount, unitCost, note, supplierId, supplierName];
}

class ProductStockDecreased extends ProductEvent {
  final String productId;
  final int amount;
  final String? note;
  const ProductStockDecreased({
    required this.productId,
    required this.amount,
    this.note,
  });
  @override
  List<Object?> get props => [productId, amount];
}

class ProductSearchRequested extends ProductEvent {
  final String query;
  const ProductSearchRequested({required this.query});
  @override
  List<Object?> get props => [query];
}
