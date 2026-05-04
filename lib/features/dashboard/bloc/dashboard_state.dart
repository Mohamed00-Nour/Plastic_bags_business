import 'package:equatable/equatable.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/product_model_new.dart';
import 'dashboard_event.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();
  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final double totalSales; // Actual sales (Delivered)
  final double expectedSales; // Pending / Approved
  final double totalProfit;
  final int activeShops;
  final int totalProducts;
  final int pendingOrders;
  final int lowStockCount;
  final List<ProductModel> topProducts;
  final List<OrderModel> recentOrders;
  final Map<String, double> monthlySales;
  final DashboardDateRange selectedRange;
  final DateTime? customStart;
  final DateTime? customEnd;

  const DashboardLoaded({
    required this.totalSales,
    required this.expectedSales,
    required this.totalProfit,
    required this.activeShops,
    required this.totalProducts,
    required this.pendingOrders,
    required this.lowStockCount,
    required this.topProducts,
    required this.recentOrders,
    required this.monthlySales,
    this.selectedRange = DashboardDateRange.all,
    this.customStart,
    this.customEnd,
  });

  @override
  List<Object?> get props => [
        totalSales,
        expectedSales,
        totalProfit,
        activeShops,
        totalProducts,
        pendingOrders,
        lowStockCount,
        selectedRange,
        customStart,
        customEnd,
      ];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError({required this.message});
  @override
  List<Object?> get props => [message];
}
