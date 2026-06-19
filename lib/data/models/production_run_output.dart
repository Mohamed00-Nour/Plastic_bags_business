import 'package:equatable/equatable.dart';

class ProductionRunOutput extends Equatable {
  final String productId;
  final String productName;
  final double quantityKg;

  const ProductionRunOutput({
    required this.productId,
    required this.productName,
    required this.quantityKg,
  });

  factory ProductionRunOutput.fromMap(Map<String, dynamic> map) {
    return ProductionRunOutput(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantityKg: (map['quantityKg'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'quantityKg': quantityKg,
      };

  ProductionRunOutput copyWith({
    String? productId,
    String? productName,
    double? quantityKg,
  }) {
    return ProductionRunOutput(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantityKg: quantityKg ?? this.quantityKg,
    );
  }

  @override
  List<Object?> get props => [productId, productName, quantityKg];
}

List<ProductionRunOutput> mergeProductionRunOutputs(
    List<ProductionRunOutput> outputs) {
  final merged = <String, ProductionRunOutput>{};
  for (final output in outputs) {
    if (output.productId.isEmpty || output.quantityKg <= 0) continue;
    final existing = merged[output.productId];
    if (existing != null) {
      merged[output.productId] = existing.copyWith(
        quantityKg: existing.quantityKg + output.quantityKg,
      );
    } else {
      merged[output.productId] = output;
    }
  }
  return merged.values.toList();
}
