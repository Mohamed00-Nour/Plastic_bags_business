import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    _customEnd = DateTime(
      event.end.year,
      event.end.month,
      event.end.day,
      23,
      59,
      59,
    );
    await _onLoad(DashboardLoadRequested(), emit);
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Future<void> _onLoad(
    DashboardEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    try {
      final startDate = _getStartDate();

      // Parallel fetch of Commercial ERP collections
      final results = await Future.wait([
        _firestore.collection('sales_invoices').get(), // 0
        _firestore.collection('buying_invoices').get(), // 1
        _firestore.collection('clients').where('isActive', isEqualTo: true).get(), // 2
        _firestore.collection('suppliers').where('isActive', isEqualTo: true).get(), // 3
        _firestore.collection('products').where('isActive', isEqualTo: true).get(), // 4
        _firestore.collection('return_invoices').get(), // 5
      ]);

      final salesSnap = results[0];
      final purchasesSnap = results[1];
      final clientsSnap = results[2];
      final suppliersSnap = results[3];
      final productsSnap = results[4];
      final returnsSnap = results[5];

      double totalSalesRevenue = 0.0;
      double totalCashCollected = 0.0;
      double totalPurchasesAmount = 0.0;
      double totalReturnsAmount = 0.0;
      double totalProfit = 0.0;
      final monthlySalesRevenue = <String, double>{};
      final monthlyPurchases = <String, double>{};

      final productList =
          productsSnap.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .toList();

      final productCostMap = <String, double>{};
      for (final p in productList) {
        productCostMap[p.id] = p.costPrice;
      }

      final recentSalesInvoices = <Map<String, dynamic>>[];

      // Process Sales Invoices
      for (final doc in salesSnap.docs) {
        final data = doc.data();
        final dt = _parseDate(data['timestamp'] ?? data['createdAt'] ?? data['date']);

        if (startDate != null && dt.isBefore(startDate)) continue;
        if (_currentRange == DashboardDateRange.custom &&
            _customEnd != null &&
            dt.isAfter(_customEnd!)) {
          continue;
        }

        final total = (data['totalAmount'] ?? 0).toDouble();
        final paid = (data['paidAmount'] ?? 0).toDouble();

        totalSalesRevenue += total;
        totalCashCollected += paid;

        // Calculate line item profit
        final items = data['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final qty = (item['quantity'] ?? 1).toDouble();
            final price = (item['unitPrice'] ?? item['price'] ?? 0).toDouble();
            final cost = (item['costPrice'] ?? productCostMap[item['productId']] ?? 0).toDouble();
            totalProfit += qty * (price - cost);
          }
        }

        // Monthly grouping
        final monthKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        monthlySalesRevenue[monthKey] = (monthlySalesRevenue[monthKey] ?? 0) + total;

        recentSalesInvoices.add({
          'id': doc.id,
          'invoiceNumber': data['invoiceNumber'] ?? 'INV-000',
          'clientName': data['clientName'] ?? 'عميل نقدي',
          'totalAmount': total,
          'paidAmount': paid,
          'remainingAmount': (data['remainingAmount'] ?? (total - paid)).toDouble(),
          'date': dt,
        });
      }

      // Sort recent invoices by date descending
      recentSalesInvoices.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      // Process Purchasing Invoices
      for (final doc in purchasesSnap.docs) {
        final data = doc.data();
        final dt = _parseDate(data['createdAt'] ?? data['timestamp'] ?? data['date']);

        if (startDate != null && dt.isBefore(startDate)) continue;
        if (_currentRange == DashboardDateRange.custom &&
            _customEnd != null &&
            dt.isAfter(_customEnd!)) {
          continue;
        }

        final total = (data['totalAmount'] ?? 0).toDouble();
        totalPurchasesAmount += total;

        final monthKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        monthlyPurchases[monthKey] = (monthlyPurchases[monthKey] ?? 0) + total;
      }

      // Process Sales Returns
      for (final doc in returnsSnap.docs) {
        final data = doc.data();
        final dt = _parseDate(data['createdAt'] ?? data['timestamp'] ?? data['date']);

        if (startDate != null && dt.isBefore(startDate)) continue;
        if (_currentRange == DashboardDateRange.custom &&
            _customEnd != null &&
            dt.isAfter(_customEnd!)) {
          continue;
        }

        final total = (data['totalAmount'] ?? data['netTotal'] ?? 0).toDouble();
        totalReturnsAmount += total;
      }

      // Process Clients Debt
      double totalClientsDebt = 0.0;
      for (final doc in clientsSnap.docs) {
        final data = doc.data();
        final bal = (data['balance'] ?? 0).toDouble();
        if (bal > 0) {
          totalClientsDebt += bal;
        }
      }

      // Process Suppliers Debt
      double totalSuppliersDebt = 0.0;
      for (final doc in suppliersSnap.docs) {
        final data = doc.data();
        final bal = (data['balance'] ?? 0).toDouble();
        if (bal > 0) {
          totalSuppliersDebt += bal;
        }
      }

      // Process Inventory Valuation & Low Stock
      double totalInventoryCostValue = 0.0;
      int lowStockCount = 0;
      for (final p in productList) {
        totalInventoryCostValue += p.stockQuantity * p.costPrice;
        if (p.isLowStock) {
          lowStockCount++;
        }
      }

      final topProducts = List<ProductModel>.from(productList)
        ..sort((a, b) => (b.stockQuantity * b.price).compareTo(a.stockQuantity * a.price));

      emit(
        DashboardLoaded(
          totalSalesRevenue: totalSalesRevenue,
          totalCashCollected: totalCashCollected,
          totalPurchasesAmount: totalPurchasesAmount,
          totalReturnsAmount: totalReturnsAmount,
          totalClientsDebt: totalClientsDebt,
          totalSuppliersDebt: totalSuppliersDebt,
          totalInventoryCostValue: totalInventoryCostValue,
          totalProfit: totalProfit - totalReturnsAmount,
          activeProductsCount: productList.length,
          lowStockCount: lowStockCount,
          totalClientsCount: clientsSnap.size,
          totalSuppliersCount: suppliersSnap.size,
          topProducts: topProducts.take(6).toList(),
          recentSalesInvoices: recentSalesInvoices.take(8).toList(),
          monthlySalesRevenue: monthlySalesRevenue,
          monthlyPurchases: monthlyPurchases,
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
