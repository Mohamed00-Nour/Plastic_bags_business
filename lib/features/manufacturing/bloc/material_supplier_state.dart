import 'package:equatable/equatable.dart';
import '../../../data/models/material_supplier_model.dart';

abstract class MaterialSupplierState extends Equatable {
  const MaterialSupplierState();
  @override
  List<Object?> get props => [];
}

class MaterialSupplierInitial extends MaterialSupplierState {}

class MaterialSupplierLoading extends MaterialSupplierState {}

class MaterialSupplierLoaded extends MaterialSupplierState {
  final List<MaterialSupplierModel> all;
  final List<MaterialSupplierModel> filtered;
  final String searchQuery;

  const MaterialSupplierLoaded({
    required this.all,
    required this.filtered,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [all, filtered, searchQuery];
}

class MaterialSupplierOperationSuccess extends MaterialSupplierState {
  final String message;
  const MaterialSupplierOperationSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class MaterialSupplierError extends MaterialSupplierState {
  final String message;
  const MaterialSupplierError({required this.message});
  @override
  List<Object?> get props => [message];
}
