import 'package:equatable/equatable.dart';

class AdditionalCost extends Equatable {
  final String label;
  final double amount;

  const AdditionalCost({required this.label, required this.amount});

  factory AdditionalCost.fromMap(Map<String, dynamic> map) {
    return AdditionalCost(
      label: map['label'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {'label': label, 'amount': amount};

  AdditionalCost copyWith({String? label, double? amount}) {
    return AdditionalCost(
      label: label ?? this.label,
      amount: amount ?? this.amount,
    );
  }

  @override
  List<Object?> get props => [label, amount];
}
