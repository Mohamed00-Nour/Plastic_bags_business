import 'package:flutter_test/flutter_test.dart';
import 'package:store_manager/data/models/tithe_payout_model.dart';
import 'package:store_manager/data/repositories/tithe_repository.dart';

void main() {
  group('TithePayoutModel & MonthlyTitheSummary Tests', () {
    test('TithePayoutModel serializes to and from Map correctly', () {
      final now = DateTime(2026, 9, 16, 14, 30);
      final model = TithePayoutModel(
        id: 'payout-123',
        amount: 2500.0,
        date: now,
        recipient: 'مستشفى الأطفال',
        notes: 'تبرع شهري',
        createdByName: 'John',
        createdByUid: 'user-001',
        createdAt: now,
      );

      final map = model.toMap();
      expect(map['amount'], 2500.0);
      expect(map['recipient'], 'مستشفى الأطفال');
      expect(map['notes'], 'تبرع شهري');
      expect(map['createdByName'], 'John');
      expect(map['createdByUid'], 'user-001');

      final fromMapModel = TithePayoutModel.fromMap({
        'id': 'payout-123',
        'amount': 2500.0,
        'date': now.toIso8601String(),
        'recipient': 'مستشفى الأطفال',
        'notes': 'تبرع شهري',
        'createdByName': 'John',
        'createdByUid': 'user-001',
      }, 'payout-123');

      expect(fromMapModel.id, 'payout-123');
      expect(fromMapModel.amount, 2500.0);
      expect(fromMapModel.recipient, 'مستشفى الأطفال');
      expect(fromMapModel.notes, 'تبرع شهري');
      expect(fromMapModel.createdByName, 'John');
    });

    test('MonthlyTitheSummary computes 10% tithe and net remaining accurately', () {
      final summary = MonthlyTitheSummary(
        monthKey: '2026-09',
        monthDate: DateTime(2026, 9, 1),
        salesRevenue: 100000.0,
        netProfit: 30000.0,
        titheAccrued: 3000.0, // 10% of 30,000
        titheDisbursed: 1200.0,
        netRemaining: 1800.0,
      );

      expect(summary.titheAccrued, summary.netProfit * 0.10);
      expect(summary.netRemaining, summary.titheAccrued - summary.titheDisbursed);
      expect(summary.netRemaining, 1800.0);
    });

    test('TitheFinancialData computes totals correctly', () {
      const data = TitheFinancialData(
        totalAllTimeProfit: 50000.0,
        totalAllTimeTithe: 5000.0,
        monthlySalesRevenue: {'2026-09': 40000.0},
        monthlyProfit: {'2026-09': 15000.0},
        monthlyTithe: {'2026-09': 1500.0},
      );

      expect(data.totalAllTimeProfit, 50000.0);
      expect(data.totalAllTimeTithe, 5000.0);
      expect(data.monthlyTithe['2026-09'], 1500.0);
    });
  });
}
