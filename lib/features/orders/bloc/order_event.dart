import 'package:equatable/equatable.dart';
import '../../../data/models/order_model.dart';

abstract class OrderEvent extends Equatable {
  const OrderEvent();
  @override
  List<Object?> get props => [];
}

class OrderLoadRequested extends OrderEvent {}

class OrderCreateRequested extends OrderEvent {
  final OrderModel order;
  const OrderCreateRequested({required this.order});
  @override
  List<Object?> get props => [order];
}

class OrderApproveRequested extends OrderEvent {
  final String orderId;
  final String approvedBy;
  const OrderApproveRequested({
    required this.orderId,
    required this.approvedBy,
  });
  @override
  List<Object?> get props => [orderId, approvedBy];
}

class OrderRejectRequested extends OrderEvent {
  final String orderId;
  final String? reason;
  const OrderRejectRequested({required this.orderId, this.reason});
  @override
  List<Object?> get props => [orderId, reason];
}

class OrderMarkDelivered extends OrderEvent {
  final String orderId;
  const OrderMarkDelivered({required this.orderId});
  @override
  List<Object?> get props => [orderId];
}

class OrderFilterByStatus extends OrderEvent {
  final OrderStatus? status;
  const OrderFilterByStatus({this.status});
  @override
  List<Object?> get props => [status];
}

class OrderSearchRequested extends OrderEvent {
  final String query;
  const OrderSearchRequested({required this.query});
  @override
  List<Object?> get props => [query];
}
