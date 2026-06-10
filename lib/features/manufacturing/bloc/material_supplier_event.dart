import 'package:equatable/equatable.dart';
import '../../../data/models/material_supplier_model.dart';

abstract class MaterialSupplierEvent extends Equatable {
  const MaterialSupplierEvent();
  @override
  List<Object?> get props => [];
}

class MaterialSupplierLoadRequested extends MaterialSupplierEvent {}

class MaterialSupplierSearchRequested extends MaterialSupplierEvent {
  final String query;
  const MaterialSupplierSearchRequested({required this.query});
  @override
  List<Object?> get props => [query];
}

class MaterialSupplierAddRequested extends MaterialSupplierEvent {
  final MaterialSupplierModel supplier;
  const MaterialSupplierAddRequested({required this.supplier});
  @override
  List<Object?> get props => [supplier];
}

class MaterialSupplierUpdateRequested extends MaterialSupplierEvent {
  final MaterialSupplierModel supplier;
  const MaterialSupplierUpdateRequested({required this.supplier});
  @override
  List<Object?> get props => [supplier];
}

class MaterialSupplierDeleteRequested extends MaterialSupplierEvent {
  final String id;
  const MaterialSupplierDeleteRequested({required this.id});
  @override
  List<Object?> get props => [id];
}
