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

  static double _toDouble(dynamic val, [double defaultVal = 0.0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? defaultVal;
    return defaultVal;
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

      // Parallel fetch of Commercial ERP collections & Manufacturing Expenses
      final results = await Future.wait([
        _firestore.collection('sales_invoices').get(), // 0
        _firestore.collection('buying_invoices').get(), // 1
        _firestore.collection('clients').where('isActive', isEqualTo: true).get(), // 2
        _firestore.collection('suppliers').where('isActive', isEqualTo: true).get(), // 3
        _firestore.collection('products').where('isActive', isEqualTo: true).get(), // 4
        _firestore.collection('return_invoices').get(), // 5
        _firestore.collectionGroup('balanceHistory').get(), // 6
        _firestore.collection('manufacturing_expenses').get(), // 7
      ]);

      final salesSnap = results[0];
      final purchasesSnap = results[1];
      final clientsSnap = results[2];
      final suppliersSnap = results[3];
      final productsSnap = results[4];
      final returnsSnap = results[5];
      final balanceHistorySnap = results[6];
      final mfgExpensesSnap = results[7];

      double totalSalesRevenue = 0.0;
      double totalCashCollected = 0.0;
      double totalPurchasesAmount = 0.0;
      double totalReturnsAmount = 0.0;
      double totalManufacturingExpenses = 0.0;
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

        final total = _toDouble(data['totalAmount']);
        final paid = _toDouble(data['paidAmount']);

        totalSalesRevenue += total;
        totalCashCollected += paid;

        // Calculate line item profit
        final dynamic itemsRaw = data['items'];
        final items = itemsRaw is List ? itemsRaw : [];
        for (final item in items) {
          if (item is Map) {
            final qty = _toDouble(item['quantity'], 1.0);
            final price = _toDouble(item['unitPrice'] ?? item['price']);
            final cost = _toDouble(item['costPrice'] ?? productCostMap[item['productId']?.toString()]);
            totalProfit += qty * (price - cost);
          }
        }

        // Monthly grouping
        final monthKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        monthlySalesRevenue[monthKey] = (monthlySalesRevenue[monthKey] ?? 0) + total;

        recentSalesInvoices.add({
          'id': doc.id,
          'invoiceNumber': data['invoiceNumber']?.toString() ?? 'INV-000',
          'clientName': data['clientName']?.toString() ?? 'عميل نقدي',
          'totalAmount': total,
          'paidAmount': paid,
          'remainingAmount': _toDouble(data['remainingAmount'], total - paid),
          'date': dt,
        });
      }

      // Sort recent invoices by date descending
      recentSalesInvoices.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      // Process Direct Client Account Payments (e.g. Add Payment from Client Page)
      for (final doc in balanceHistorySnap.docs) {
        // Ensure record belongs to a client subcollection
        if (!doc.reference.path.contains('clients/')) continue;

        final data = doc.data();
        final type = data['type']?.toString().toLowerCase() ?? '';
        if (type != 'payment') continue;

        // Skip invoice payments already accounted for in salesSnap.docs paidAmount
        final invoiceId = data['invoiceId']?.toString() ?? '';
        if (invoiceId.isNotEmpty) continue;

        final dt = _parseDate(data['timestamp'] ?? data['createdAt']);
        if (startDate != null && dt.isBefore(startDate)) continue;
        if (_currentRange == DashboardDateRange.custom &&
            _customEnd != null &&
            dt.isAfter(_customEnd!)) {
          continue;
        }

        final amt = _toDouble(data['amount']);
        totalCashCollected += amt;
      }

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

        final total = _toDouble(data['totalAmount']);
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

        final total = _toDouble(data['totalAmount'] ?? data['netTotal']);
        totalReturnsAmount += total;
      }

      // Process Manufacturing Expenses (التصنيع -> المصاريف)
      for (final doc in mfgExpensesSnap.docs) {
        final data = doc.data();
        final dt = _parseDate(
          data['date'] ?? data['createdAt'] ?? data['timestamp'],
        );

        if (startDate != null && dt.isBefore(startDate)) continue;
        if (_currentRange == DashboardDateRange.custom &&
            _customEnd != null &&
            dt.isAfter(_customEnd!)) {
          continue;
        }

        final amount = _toDouble(data['amount']);
        totalManufacturingExpenses += amount;
      }

      // Process Clients Debt
      double totalClientsDebt = 0.0;
      for (final doc in clientsSnap.docs) {
        final data = doc.data();
        final bal = _toDouble(data['balance'] ?? data['totalBalance']);
        if (bal > 0) {
          totalClientsDebt += bal;
        }
      }

      // Process Suppliers Debt
      double totalSuppliersDebt = 0.0;
      for (final doc in suppliersSnap.docs) {
        final data = doc.data();
        final bal = _toDouble(data['balance'] ?? data['totalBalance']);
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
          totalManufacturingExpenses: totalManufacturingExpenses,
          totalProfit:
              totalProfit - totalReturnsAmount - totalManufacturingExpenses,
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
