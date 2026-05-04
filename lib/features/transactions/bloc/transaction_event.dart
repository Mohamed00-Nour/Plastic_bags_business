import 'package:equatable/equatable.dart';
import '../../../data/models/transaction_model.dart';

abstract class TransactionEvent extends Equatable {
  const TransactionEvent();
  @override
  List<Object?> get props => [];
}

class TransactionLoadRequested extends TransactionEvent {}

class TransactionLoadByShop extends TransactionEvent {
  final String shopId;
  const TransactionLoadByShop({required this.shopId});
  @override
  List<Object?> get props => [shopId];
}

class TransactionLoadBySupplier extends TransactionEvent {
  final String supplierId;
  const TransactionLoadBySupplier({required this.supplierId});
  @override
  List<Object?> get props => [supplierId];
}

class TransactionFilterByType extends TransactionEvent {
  final TransactionType? type;
  const TransactionFilterByType({this.type});
  @override
  List<Object?> get props => [type];
}

class TransactionSearchRequested extends TransactionEvent {
  final String query;
  const TransactionSearchRequested({required this.query});
  @override
  List<Object?> get props => [query];
}
