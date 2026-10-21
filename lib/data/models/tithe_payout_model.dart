import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum TitheDateRange {
  all,
  today,
  thisWeek,
  thisMonth,
  lastMonth,
  thisYear,
  custom,
}

class TithePayoutModel extends Equatable {
  final String id;
  final double amount;
  final DateTime date;
  final String recipient;
  final String notes;
  final String createdByName;
  final String createdByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TithePayoutModel({
    required this.id,
    required this.amount,
    required this.date,
    required this.recipient,
    this.notes = '',
    this.createdByName = '',
    this.createdByUid = '',
    this.createdAt,
    this.updatedAt,
  });

  factory TithePayoutModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return TithePayoutModel.fromMap(data, doc.id);
  }

  factory TithePayoutModel.fromMap(Map<String, dynamic> data, [String id = '']) {
    return TithePayoutModel(
      id: id.isNotEmpty ? id : (data['id']?.toString() ?? ''),
      amount: (data['amount'] ?? 0).toDouble(),
      date: _parseDateTime(data['date'] ?? data['createdAt']),
      recipient: data['recipient']?.toString() ?? data['beneficiary']?.toString() ?? '',
      notes: data['notes']?.toString() ?? data['description']?.toString() ?? '',
      createdByName: data['createdByName']?.toString() ?? data['userName']?.toString() ?? '',
      createdByUid: data['createdByUid']?.toString() ?? data['userId']?.toString() ?? '',
      createdAt: data['createdAt'] != null ? _parseDateTime(data['createdAt']) : null,
      updatedAt: data['updatedAt'] != null ? _parseDateTime(data['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'recipient': recipient.trim(),
      'notes': notes.trim(),
      'createdByName': createdByName.trim(),
      'createdByUid': createdByUid.trim(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  TithePayoutModel copyWith({
    String? id,
    double? amount,
    DateTime? date,
    String? recipient,
    String? notes,
    String? createdByName,
    String? createdByUid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TithePayoutModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      recipient: recipient ?? this.recipient,
      notes: notes ?? this.notes,
      createdByName: createdByName ?? this.createdByName,
      createdByUid: createdByUid ?? this.createdByUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      if (value > 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  @override
  List<Object?> get props => [
        id,
        amount,
        date,
        recipient,
        notes,
        createdByName,
        createdByUid,
        createdAt,
        updatedAt,
      ];
}

class MonthlyTitheSummary extends Equatable {
  final String monthKey; // e.g. "2026-09"
  final DateTime monthDate;
  final double salesRevenue;
  final double netProfit;
  final double titheAccrued; // 10% of net profit (or 0 if negative)
  final double titheDisbursed; // sum of payouts in this month
  final double netRemaining; // titheAccrued - titheDisbursed

  const MonthlyTitheSummary({
    required this.monthKey,
    required this.monthDate,
    required this.salesRevenue,
    required this.netProfit,
    required this.titheAccrued,
    required this.titheDisbursed,
    required this.netRemaining,
  });

  @override
  List<Object?> get props => [
        monthKey,
        monthDate,
        salesRevenue,
        netProfit,
        titheAccrued,
        titheDisbursed,
        netRemaining,
      ];
}
