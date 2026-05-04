import 'package:equatable/equatable.dart';
import '../../../data/models/product_model_new.dart';

abstract class ProductState extends Equatable {
  const ProductState();
  @override
  List<Object?> get props => [];
}

class ProductInitial extends ProductState {}

class ProductLoading extends ProductState {}

class ProductLoaded extends ProductState {
  final List<ProductModel> products;
  final List<ProductModel> filteredProducts;
  final String searchQuery;

  const ProductLoaded({
    required this.products,
    required this.filteredProducts,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [products, filteredProducts, searchQuery];
}

class ProductOperationSuccess extends ProductState {
  final String message;
  const ProductOperationSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class ProductError extends ProductState {
  final String message;
  const ProductError({required this.message});
  @override
  List<Object?> get props => [message];
}
