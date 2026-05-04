import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import 'report_event.dart';
import 'report_state.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final OrderRepository _orderRepository;
  final TransactionRepository _transactionRepository;

  ReportBloc({
    required OrderRepository orderRepository,
    required TransactionRepository transactionRepository,
  })  : _orderRepository = orderRepository,
        _transactionRepository = transactionRepository,
        super(ReportInitial()) {
    on<ReportLoadRequested>(_onLoad);
  }

  Future<void> _onLoad(
    ReportLoadRequested event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());
    try {
      final results = await Future.wait([
        _orderRepository.getOrdersBetween(event.startDate, event.endDate),
        _transactionRepository.getTransactionsBetween(
            event.startDate, event.endDate),
      ]);

      final orders = results[0] as List<OrderModel>;
      final transactions = results[1] as List<TransactionModel>;

      double totalSales = 0;
      double totalCharges = 0;
      int approvedCount = 0;
      int rejectedCount = 0;
      final dailySales = <String, double>{};

      for (final order in orders) {
        if (order.status == OrderStatus.approved ||
            order.status == OrderStatus.delivered) {
          totalSales += order.totalPrice;
          approvedCount++;

          final key =
              '${order.createdAt.month}/${order.createdAt.day}';
          dailySales[key] = (dailySales[key] ?? 0) + order.totalPrice;
        }
        if (order.status == OrderStatus.rejected) {
          rejectedCount++;
        }
      }

      for (final t in transactions) {
        if (t.type == TransactionType.balanceCharge) {
          totalCharges += t.amount;
        }
      }

      emit(ReportLoaded(
        totalSales: totalSales,
        totalCharges: totalCharges,
        orderCount: orders.length,
        approvedCount: approvedCount,
        rejectedCount: rejectedCount,
        orders: orders,
        transactions: transactions,
        dailySales: dailySales,
        startDate: event.startDate,
        endDate: event.endDate,
      ));
    } catch (e) {
      emit(ReportError(message: e.toString()));
    }
  }
}
