import 'package:equatable/equatable.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/transaction_model.dart';

abstract class ReportState extends Equatable {
  const ReportState();
  @override
  List<Object?> get props => [];
}

class ReportInitial extends ReportState {}

class ReportLoading extends ReportState {}

class ReportLoaded extends ReportState {
  final double totalSales;
  final double totalCharges;
  final int orderCount;
  final int approvedCount;
  final int rejectedCount;
  final List<OrderModel> orders;
  final List<TransactionModel> transactions;
  final Map<String, double> dailySales;
  final DateTime startDate;
  final DateTime endDate;

  const ReportLoaded({
    required this.totalSales,
    required this.totalCharges,
    required this.orderCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.orders,
    required this.transactions,
    required this.dailySales,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props =>
      [totalSales, totalCharges, orderCount, startDate, endDate];
}

class ReportPdfGenerated extends ReportState {
  final String message;
  const ReportPdfGenerated({required this.message});
  @override
  List<Object?> get props => [message];
}

class ReportError extends ReportState {
  final String message;
  const ReportError({required this.message});
  @override
  List<Object?> get props => [message];
}
