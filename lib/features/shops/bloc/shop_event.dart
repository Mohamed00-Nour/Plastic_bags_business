import 'package:equatable/equatable.dart';
import '../../../data/models/shop_model_new.dart';

abstract class ShopEvent extends Equatable {
  const ShopEvent();
  @override
  List<Object?> get props => [];
}

class ShopLoadRequested extends ShopEvent {}

class ShopAddRequested extends ShopEvent {
  final ShopModel shop;
  const ShopAddRequested({required this.shop});
  @override
  List<Object?> get props => [shop];
}

class ShopAddWithAccountRequested extends ShopEvent {
  final ShopModel shop;
  final String email;
  final String password;
  const ShopAddWithAccountRequested({
    required this.shop,
    required this.email,
    required this.password,
  });
  @override
  List<Object?> get props => [shop, email, password];
}

class ShopUpdateRequested extends ShopEvent {
  final ShopModel shop;
  const ShopUpdateRequested({required this.shop});
  @override
  List<Object?> get props => [shop];
}

class ShopDeleteRequested extends ShopEvent {
  final String shopId;
  const ShopDeleteRequested({required this.shopId});
  @override
  List<Object?> get props => [shopId];
}

class ShopSearchRequested extends ShopEvent {
  final String query;
  const ShopSearchRequested({required this.query});
  @override
  List<Object?> get props => [query];
}
