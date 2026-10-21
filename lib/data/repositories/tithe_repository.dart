import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model_new.dart';
import '../models/tithe_payout_model.dart';

class TitheFinancialData {
  final double totalAllTimeProfit;
  final double totalAllTimeTithe;
  final Map<String, double> monthlySalesRevenue;
  final Map<String, double> monthlyProfit;
  final Map<String, double> monthlyTithe;

  const TitheFinancialData({
    required this.totalAllTimeProfit,
    required this.totalAllTimeTithe,
    required this.monthlySalesRevenue,
    required this.monthlyProfit,
    required this.monthlyTithe,
  });

  factory TitheFinancialData.empty() {
    return const TitheFinancialData(
      totalAllTimeProfit: 0.0,
      totalAllTimeTithe: 0.0,
      monthlySalesRevenue: {},
      monthlyProfit: {},
      monthlyTithe: {},
    );
  }
}

class TitheRepository {
  final FirebaseFirestore _firestore;

  TitheRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _payoutsCollection =>
      _firestore.collection('tithe_payouts');

  /// Stream of all tithe payouts ordered by date descending
  Stream<List<TithePayoutModel>> getPayoutsStream() {
    return _payoutsCollection
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => TithePayoutModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  /// Create a new payout record
  Future<String> addPayout(TithePayoutModel payout) async {
    final docRef = await _payoutsCollection.add(payout.toMap());
    return docRef.id;
  }

  /// Update an existing payout record
  Future<void> updatePayout(TithePayoutModel payout) async {
    await _payoutsCollection.doc(payout.id).update(payout.toMap());
  }

  /// Delete a payout record
  Future<void> deletePayout(String id) async {
    await _payoutsCollection.doc(id).delete();
  }

  /// Calculate all-time and monthly profit & 10% tithe accruals
  Future<TitheFinancialData> calculateTitheFinancials() async {
    try {
      final results = await Future.wait([
        _firestore.collection('sales_invoices').get(),
        _firestore.collection('return_invoices').get(),
        _firestore.collection('manufacturing_expenses').get(),
        _firestore.collection('products').get(),
      ]);

      final salesSnap = results[0];
      final returnsSnap = results[1];
      final mfgExpensesSnap = results[2];
      final productsSnap = results[3];

      // Cost price map
      final productCostMap = <String, double>{};
      for (final doc in productsSnap.docs) {
        final p = ProductModel.fromFirestore(doc);
        productCostMap[p.id] = p.costPrice;
      }

      final monthlySalesRevenue = <String, double>{};
      final monthlyItemProfit = <String, double>{};
      final monthlyReturns = <String, double>{};
      final monthlyMfgExpenses = <String, double>{};

      // 1. Process Sales Invoices
      for (final doc in salesSnap.docs) {
        final data = doc.data();
        final dt = _parseDate(data['timestamp'] ?? data['createdAt'] ?? data['date']);
        final monthKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

        final total = _toDouble(data['totalAmount']);
        monthlySalesRevenue[monthKey] = (monthlySalesRevenue[monthKey] ?? 0) + total;

        final dynamic itemsRaw = data['items'];
        final items = itemsRaw is List ? itemsRaw : [];
        double invoiceProfit = 0.0;
        for (final item in items) {
          if (item is Map) {
            final qty = _toDouble(item['quantity'], 1.0);
            final price = _toDouble(item['unitPrice'] ?? item['price']);
            final cost = _toDouble(item['costPrice'] ?? productCostMap[item['productId']?.toString()]);
            invoiceProfit += qty * (price - cost);
          }
        }
        monthlyItemProfit[monthKey] = (monthlyItemProfit[monthKey] ?? 0) + invoiceProfit;
      }

      // 2. Process Returns
      for (final doc in returnsSnap.docs) {
        final data = doc.data();
        final dt = _parseDate(data['createdAt'] ?? data['timestamp'] ?? data['date']);
        final monthKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        final total = _toDouble(data['totalAmount'] ?? data['netTotal']);
        monthlyReturns[monthKey] = (monthlyReturns[monthKey] ?? 0) + total;
      }

      // 3. Process Manufacturing Expenses
      for (final doc in mfgExpensesSnap.docs) {
        final data = doc.data();
        final dt = _parseDate(data['date'] ?? data['createdAt'] ?? data['timestamp']);
        final monthKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        final amount = _toDouble(data['amount']);
        monthlyMfgExpenses[monthKey] = (monthlyMfgExpenses[monthKey] ?? 0) + amount;
      }

      // Aggregate distinct month keys
      final allMonthKeys = <String>{
        ...monthlySalesRevenue.keys,
        ...monthlyItemProfit.keys,
        ...monthlyReturns.keys,
        ...monthlyMfgExpenses.keys,
      };

      final monthlyProfit = <String, double>{};
      final monthlyTithe = <String, double>{};

      double totalAllTimeProfit = 0.0;
      double totalAllTimeTithe = 0.0;

      for (final key in allMonthKeys) {
        final itemProfit = monthlyItemProfit[key] ?? 0.0;
        final returns = monthlyReturns[key] ?? 0.0;
        final mfgExp = monthlyMfgExpenses[key] ?? 0.0;

        final netProf = itemProfit - returns - mfgExp;
        monthlyProfit[key] = netProf;

        final tithe = netProf > 0 ? (netProf * 0.10) : 0.0;
        monthlyTithe[key] = tithe;

        totalAllTimeProfit += netProf;
        totalAllTimeTithe += tithe;
      }

      return TitheFinancialData(
        totalAllTimeProfit: totalAllTimeProfit,
        totalAllTimeTithe: totalAllTimeTithe,
        monthlySalesRevenue: monthlySalesRevenue,
        monthlyProfit: monthlyProfit,
        monthlyTithe: monthlyTithe,
      );
    } catch (_) {
      return TitheFinancialData.empty();
    }
  }

  static double _toDouble(dynamic val, [double defaultVal = 0.0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? defaultVal;
    return defaultVal;
  }

  static DateTime _parseDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) {
      if (val > 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(val);
      }
      return DateTime.fromMillisecondsSinceEpoch(val * 1000);
    }
    if (val is String) {
      final parsed = DateTime.tryParse(val);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }
}
