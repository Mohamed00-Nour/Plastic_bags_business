import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/current_user_service.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/stock_log_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/shop_repository.dart';
import '../../../data/repositories/stock_log_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import 'order_event.dart';
import 'order_state.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository _orderRepository;
  final ProductRepository _productRepository;
  final ShopRepository _shopRepository;
  final TransactionRepository _transactionRepository;
  final StockLogRepository _stockLogRepository;
  StreamSubscription? _subscription;
  List<OrderModel> _allOrders = [];
  OrderStatus? _currentFilter;

  OrderBloc({
    required OrderRepository orderRepository,
    required ProductRepository productRepository,
    required ShopRepository shopRepository,
    required TransactionRepository transactionRepository,
    required StockLogRepository stockLogRepository,
  }) : _orderRepository = orderRepository,
       _productRepository = productRepository,
       _shopRepository = shopRepository,
       _transactionRepository = transactionRepository,
       _stockLogRepository = stockLogRepository,
       super(OrderInitial()) {
    on<OrderLoadRequested>(_onLoad);
    on<OrderCreateRequested>(_onCreate);
    on<OrderApproveRequested>(_onApprove);
    on<OrderRejectRequested>(_onReject);
    on<OrderMarkDelivered>(_onMarkDelivered);
    on<OrderFilterByStatus>(_onFilterByStatus);
    on<OrderSearchRequested>(_onSearch);
  }

  Future<void> _onLoad(
    OrderLoadRequested event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());
    await _subscription?.cancel();
    _subscription = _orderRepository.getOrders().listen(
      (orders) {
        _allOrders = orders;
        if (!isClosed) {
          add(const OrderSearchRequested(query: ''));
        }
      },
      onError: (error) {
        if (!isClosed) {
          emit(OrderError(message: error.toString()));
        }
      },
    );
  }

  void _onSearch(OrderSearchRequested event, Emitter<OrderState> emit) {
    final query = event.query.toLowerCase();
    var filtered = _allOrders.toList();

    if (_currentFilter != null) {
      filtered = filtered.where((o) => o.status == _currentFilter).toList();
    }

    if (query.isNotEmpty) {
      filtered =
          filtered
              .where(
                (o) =>
                    o.shopName.toLowerCase().contains(query) ||
                    o.id.toLowerCase().contains(query),
              )
              .toList();
    }

    emit(
      OrderLoaded(
        orders: _allOrders,
        filteredOrders: filtered,
        filterStatus: _currentFilter,
        searchQuery: event.query,
      ),
    );
  }

  void _onFilterByStatus(OrderFilterByStatus event, Emitter<OrderState> emit) {
    _currentFilter = event.status;
    add(const OrderSearchRequested(query: ''));
  }

  Future<void> _onCreate(
    OrderCreateRequested event,
    Emitter<OrderState> emit,
  ) async {
    try {
      await _orderRepository.createOrder(event.order);
      emit(const OrderOperationSuccess(message: 'Order created successfully'));
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }

  Future<void> _onApprove(
    OrderApproveRequested event,
    Emitter<OrderState> emit,
  ) async {
    try {
      await _orderRepository.updateOrderStatus(
        event.orderId,
        OrderStatus.approved,
        approvedBy: event.approvedBy,
      );

      emit(const OrderOperationSuccess(message: 'Order approved successfully'));
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }

  Future<void> _onReject(
    OrderRejectRequested event,
    Emitter<OrderState> emit,
  ) async {
    try {
      await _orderRepository.updateOrderStatus(
        event.orderId,
        OrderStatus.rejected,
        rejectionReason: event.reason,
      );
      emit(const OrderOperationSuccess(message: 'Order rejected'));
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }

  Future<void> _onMarkDelivered(
    OrderMarkDelivered event,
    Emitter<OrderState> emit,
  ) async {
    try {
      final order = await _orderRepository.getOrder(event.orderId);

      // Deduct stock for each item upon delivery
      for (final item in order.items) {
        final product = await _productRepository.getProduct(item.productId);
        await _productRepository.decrementStock(item.productId, item.quantity);

        await _stockLogRepository.addLog(
          StockLogModel(
            id: const Uuid().v4(),
            productId: item.productId,
            productName: item.productName,
            type: StockMovementType.outgoing,
            quantity: item.quantity,
            stockBefore: product.stockQuantity,
            stockAfter: product.stockQuantity - item.quantity,
            referenceId: order.id,
            note: 'Order delivered - ${order.shopName}',
            createdBy: CurrentUserService.instance.userName,
            createdAt: DateTime.now(),
          ),
        );
      }

      await _shopRepository.addToTotalPurchases(order.shopId, order.totalPrice);

      // Cash Collection (Revenue transaction)
      await _transactionRepository.addTransaction(
        TransactionModel(
          id: const Uuid().v4(),
          shopId: order.shopId,
          shopName: order.shopName,
          type: TransactionType.purchase,
          amount: order.totalPrice,
          balanceAfter: 0,
          orderId: order.id,
          description: 'Order # Delivered (Payment Received)',
          createdBy: CurrentUserService.instance.userName,
          createdAt: DateTime.now(),
        ),
      );

      await _orderRepository.updateOrderStatus(
        event.orderId,
        OrderStatus.delivered,
      );

      emit(
        const OrderOperationSuccess(
          message: 'Order marked as delivered and payment collected',
        ),
      );
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
