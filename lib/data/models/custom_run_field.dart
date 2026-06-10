import 'package:equatable/equatable.dart';

class CustomRunField extends Equatable {
  final String label;
  final double value;

  const CustomRunField({
    required this.label,
    required this.value,
  });

  factory CustomRunField.fromMap(Map<String, dynamic> map) {
    return CustomRunField(
      label: map['label'] ?? '',
      value: (map['value'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'value': value,
        'type': 'cost',
      };

  CustomRunField copyWith({
    String? label,
    double? value,
  }) {
    return CustomRunField(
      label: label ?? this.label,
      value: value ?? this.value,
    );
  }

  @override
  List<Object?> get props => [label, value];
}
