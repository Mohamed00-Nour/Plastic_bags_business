import 'package:equatable/equatable.dart';
import '../../../data/models/supplier_model_new.dart';

abstract class SupplierState extends Equatable {
  const SupplierState();
  @override
  List<Object?> get props => [];
}

class SupplierInitial extends SupplierState {}

class SupplierLoading extends SupplierState {}

class SupplierLoaded extends SupplierState {
  final List<SupplierModel> suppliers;
  final List<SupplierModel> filteredSuppliers;
  final String searchQuery;

  const SupplierLoaded({
    required this.suppliers,
    required this.filteredSuppliers,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [suppliers, filteredSuppliers, searchQuery];
}

class SupplierOperationSuccess extends SupplierState {
  final String message;
  const SupplierOperationSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class SupplierError extends SupplierState {
  final String message;
  const SupplierError({required this.message});
  @override
  List<Object?> get props => [message];
}
