import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/product_model_new.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DashboardDateRange _currentRange = DashboardDateRange.today;
  DateTime? _customStart;
  DateTime? _customEnd;

  DashboardBloc() : super(DashboardInitial()) {
    on<DashboardLoadRequested>(_onLoad);
    on<DashboardRefreshRequested>(_onLoad);
    on<DashboardFilterChanged>(_onFilterChanged);
    on<DashboardCustomRangeChanged>(_onCustomRangeChanged);
  }

  DateTime? _getStartDate() {
    final now = DateTime.now();
    switch (_currentRange) {
      case DashboardDateRange.today:
        return DateTime(now.year, now.month, now.day);
      case DashboardDateRange.week:
        return now.subtract(const Duration(days: 7));
      case DashboardDateRange.month:
        return DateTime(now.year, now.month, 1);
      case DashboardDateRange.year:
        return DateTime(now.year, 1, 1);
      case DashboardDateRange.all:
        return null;
      case DashboardDateRange.custom:
        return _customStart;
    }
  }

  Future<void> _onFilterChanged(
    DashboardFilterChanged event,
    Emitter<DashboardState> emit,
  ) async {
    _currentRange = event.range;
    await _onLoad(DashboardLoadRequested(), emit);
  }

  Future<void> _onCustomRangeChanged(
    DashboardCustomRangeChanged event,
    Emitter<DashboardState> emit,
  ) async {
    _currentRange = DashboardDateRange.custom;
    _customStart = event.start;
    _customEnd = DateTime(event.end.year, event.end.month, event.end.day, 23, 59, 59);
    await _onLoad(DashboardLoadRequested(), emit);
  }

  Future<void> _onLoad(
    DashboardEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    try {
      final startDate = _getStartDate();

      Future<QuerySnapshot> getOrders(List<String> statuses) {
        var query = _firestore
            .collection('orders')
            .where('status', whereIn: statuses);
        if (startDate != null) {
          query = query.where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          );
        }
        if (_currentRange == DashboardDateRange.custom && _customEnd != null) {
          query = query.where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(_customEnd!),
          );
        }
        return query.get();
      }

      // We can fetch all needed data in parallel
      final results = await Future.wait([
        getOrders(['delivered']), // 0: Actual Sales(profitable)
        getOrders(['pending', 'approved']), // 1: Expected Sales
        _firestore
            .collection('shops')
            .where('isActive', isEqualTo: true)
            .get(), // 2
        _firestore
            .collection('products')
            .where('isActive', isEqualTo: true)
            .get(), // 3
        _firestore
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get(), // 4
      ]);

      final deliveredOrders = results[0];
      final pendingAndApprovedOrders = results[1];
      final shops = results[2];
      final products = results[3];
      final recentOrdersSnap = results[4];

      double totalSales = 0;
      double expectedSales = 0;
      double totalProfit = 0;
      final monthlySales = <String, double>{};

      final productList =
          products.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
      final productCostMap = <String, double>{};
      for (final product in productList) {
        productCostMap[product.id] = product.costPrice;
      }

      // Actual Sales (Delivered Only)
      for (final doc in deliveredOrders.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['totalPrice'] ?? 0).toDouble();
        totalSales += amount;

        final items = data['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          final qty = (itemMap['quantity'] ?? 0).toInt();
          final unitPrice = (itemMap['unitPrice'] ?? 0).toDouble();
          final costPrice = productCostMap[itemMap['productId']] ?? 0.0;
          totalProfit += qty * (unitPrice - costPrice);
        }

        // monthly chart stats
        final date = (data['createdAt'] as Timestamp?)?.toDate();
        if (date != null) {
          final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          monthlySales[key] = (monthlySales[key] ?? 0) + amount;
        }
      }

      // Expected Sales (Pending / Approved)
      for (final doc in pendingAndApprovedOrders.docs) {
        final data = doc.data() as Map<String, dynamic>;
        expectedSales += (data['totalPrice'] ?? 0).toDouble();
      }

      final lowStockCount = productList.where((p) => p.isLowStock).length;
      final topProducts = List<ProductModel>.from(productList)
        ..sort((a, b) => b.price.compareTo(a.price));
      final recentOrders =
          recentOrdersSnap.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList();

      emit(
        DashboardLoaded(
          totalSales: totalSales,
          expectedSales: expectedSales,
          totalProfit: totalProfit,
          activeShops: shops.size,
          totalProducts: products.size,
          pendingOrders: pendingAndApprovedOrders.size,
          lowStockCount: lowStockCount,
          topProducts: topProducts.take(5).toList(),
          recentOrders: recentOrders,
          monthlySales: monthlySales,
          selectedRange: _currentRange,
          customStart: _customStart,
          customEnd: _customEnd,
        ),
      );
    } catch (e) {
      emit(DashboardError(message: e.toString()));
    }
  }
}
