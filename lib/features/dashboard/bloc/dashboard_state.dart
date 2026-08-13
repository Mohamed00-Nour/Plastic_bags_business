import 'package:equatable/equatable.dart';
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
  final double totalSalesRevenue;
  final double totalCashCollected;
  final double totalPurchasesAmount;
  final double totalReturnsAmount;
  final double totalClientsDebt;
  final double totalSuppliersDebt;
  final double totalInventoryCostValue;
  final double totalProfit;
  final int activeProductsCount;
  final int lowStockCount;
  final int totalClientsCount;
  final int totalSuppliersCount;
  final List<ProductModel> topProducts;
  final List<Map<String, dynamic>> recentSalesInvoices;
  final Map<String, double> monthlySalesRevenue;
  final Map<String, double> monthlyPurchases;
  final DashboardDateRange selectedRange;
  final DateTime? customStart;
  final DateTime? customEnd;

  const DashboardLoaded({
    required this.totalSalesRevenue,
    required this.totalCashCollected,
    required this.totalPurchasesAmount,
    required this.totalReturnsAmount,
    required this.totalClientsDebt,
    required this.totalSuppliersDebt,
    required this.totalInventoryCostValue,
    required this.totalProfit,
    required this.activeProductsCount,
    required this.lowStockCount,
    required this.totalClientsCount,
    required this.totalSuppliersCount,
    required this.topProducts,
    required this.recentSalesInvoices,
    required this.monthlySalesRevenue,
    required this.monthlyPurchases,
    this.selectedRange = DashboardDateRange.all,
    this.customStart,
    this.customEnd,
  });

  @override
  List<Object?> get props => [
        totalSalesRevenue,
        totalCashCollected,
        totalPurchasesAmount,
        totalReturnsAmount,
        totalClientsDebt,
        totalSuppliersDebt,
        totalInventoryCostValue,
        totalProfit,
        activeProductsCount,
        lowStockCount,
        totalClientsCount,
        totalSuppliersCount,
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
