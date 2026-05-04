import 'package:equatable/equatable.dart';
import '../../../data/models/shop_model_new.dart';

abstract class ShopState extends Equatable {
  const ShopState();
  @override
  List<Object?> get props => [];
}

class ShopInitial extends ShopState {}

class ShopLoading extends ShopState {}

class ShopLoaded extends ShopState {
  final List<ShopModel> shops;
  final List<ShopModel> filteredShops;
  final String searchQuery;

  const ShopLoaded({
    required this.shops,
    required this.filteredShops,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [shops, filteredShops, searchQuery];
}

class ShopOperationSuccess extends ShopState {
  final String message;
  const ShopOperationSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class ShopError extends ShopState {
  final String message;
  const ShopError({required this.message});
  @override
  List<Object?> get props => [message];
}
