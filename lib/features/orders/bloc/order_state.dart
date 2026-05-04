import 'package:equatable/equatable.dart';
import '../../../data/models/order_model.dart';

abstract class OrderState extends Equatable {
  const OrderState();
  @override
  List<Object?> get props => [];
}

class OrderInitial extends OrderState {}

class OrderLoading extends OrderState {}

class OrderLoaded extends OrderState {
  final List<OrderModel> orders;
  final List<OrderModel> filteredOrders;
  final OrderStatus? filterStatus;
  final String searchQuery;

  const OrderLoaded({
    required this.orders,
    required this.filteredOrders,
    this.filterStatus,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [orders, filteredOrders, filterStatus, searchQuery];
}

class OrderOperationSuccess extends OrderState {
  final String message;
  const OrderOperationSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class OrderError extends OrderState {
  final String message;
  const OrderError({required this.message});
  @override
  List<Object?> get props => [message];
}
