import 'package:flutter_test/flutter_test.dart';

import '../tool/audit_client_overpayments.dart';

void main() {
  test('audit finds legacy overpayments and skips corrected invoices', () {
    final snapshot = <String, dynamic>{
      'clients': [
        {'id': 'c1', 'name': 'Client', 'balance': 500},
      ],
      'sales_invoices': [
        {
          'id': 'old',
          'clientId': 'c1',
          'totalAmount': 500,
          'paidAmount': 2000,
          'remainingAmount': 0,
        },
        {
          'id': 'fixed',
          'clientId': 'c1',
          'totalAmount': 500,
          'paidAmount': 2000,
          'remainingAmount': -1500,
        },
        {
          'id': 'unpaid',
          'clientId': 'c1',
          'totalAmount': 500,
          'paidAmount': 0,
          'remainingAmount': 500,
        },
        {
          'id': 'unknown',
          'clientId': 'c2',
          'totalAmount': 500,
          'paidAmount': 1000,
        },
      ],
    };
    final report = buildOverpaymentAudit(snapshot);
    expect(report['readOnly'], isTrue);
    expect(report['invoicesScanned'], 4);
    final candidates = report['candidates'] as List;
    expect(candidates.map((item) => item['invoiceId']), ['old', 'unknown']);
    expect(candidates.first['potentialUncreditedAmount'], 1500);
    expect(candidates.last['potentialUncreditedAmount'], isNull);
    expect((report['clientsToReview'] as List).single['currentBalance'], 500);
    expect(
      (report['clientsToReview'] as List).single['potentialUncreditedAmount'],
      1500,
    );
    expect((snapshot['sales_invoices'] as List).first['remainingAmount'], 0);
    expect(buildOverpaymentAudit(snapshot), equals(report));
  });
}
