import 'package:equatable/equatable.dart';
import '../../../data/models/raw_material_model.dart';

abstract class RawMaterialEvent extends Equatable {
  const RawMaterialEvent();
  @override
  List<Object?> get props => [];
}

class RawMaterialLoadRequested extends RawMaterialEvent {}

class RawMaterialSearchRequested extends RawMaterialEvent {
  final String query;
  const RawMaterialSearchRequested({required this.query});
  @override
  List<Object?> get props => [query];
}

class RawMaterialAddRequested extends RawMaterialEvent {
  final RawMaterialModel material;
  const RawMaterialAddRequested({required this.material});
  @override
  List<Object?> get props => [material];
}

class RawMaterialUpdateRequested extends RawMaterialEvent {
  final RawMaterialModel material;
  const RawMaterialUpdateRequested({required this.material});
  @override
  List<Object?> get props => [material];
}

class RawMaterialDeleteRequested extends RawMaterialEvent {
  final String id;
  const RawMaterialDeleteRequested({required this.id});
  @override
  List<Object?> get props => [id];
}

class RawMaterialStockInRequested extends RawMaterialEvent {
  final String materialId;
  final String materialName;
  final double quantityKg;
  final double purchasePricePerKg;
  final double currentStock;
  final double currentPricePerKg;
  final String? note;
  final String? supplierId;
  final String? supplierName;

  const RawMaterialStockInRequested({
    required this.materialId,
    required this.materialName,
    required this.quantityKg,
    required this.purchasePricePerKg,
    required this.currentStock,
    required this.currentPricePerKg,
    this.note,
    this.supplierId,
    this.supplierName,
  });

  @override
  List<Object?> get props =>
      [materialId, quantityKg, purchasePricePerKg, note];
}

class RawMaterialQuantityAddRequested extends RawMaterialEvent {
  final String materialId;
  final String materialName;
  final double quantityKg;
  final double purchasePricePerKg;
  final double currentStock;
  final double currentPricePerKg;
  final String? note;
  final String? supplierId;
  final String? supplierName;

  const RawMaterialQuantityAddRequested({
    required this.materialId,
    required this.materialName,
    required this.quantityKg,
    required this.purchasePricePerKg,
    required this.currentStock,
    required this.currentPricePerKg,
    this.note,
    this.supplierId,
    this.supplierName,
  });

  @override
  List<Object?> get props =>
      [materialId, quantityKg, purchasePricePerKg, note, supplierId];
}

class RawMaterialQuantityReduceRequested extends RawMaterialEvent {
  final String materialId;
  final String materialName;
  final double quantityKg;
  final double currentStock;
  final String? note;

  const RawMaterialQuantityReduceRequested({
    required this.materialId,
    required this.materialName,
    required this.quantityKg,
    required this.currentStock,
    this.note,
  });

  @override
  List<Object?> get props => [materialId, quantityKg, note];
}
