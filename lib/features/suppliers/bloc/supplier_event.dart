import 'package:equatable/equatable.dart';
import '../../../data/models/supplier_model_new.dart';

abstract class SupplierEvent extends Equatable {
  const SupplierEvent();
  @override
  List<Object?> get props => [];
}

class SupplierLoadRequested extends SupplierEvent {}

class SupplierAddRequested extends SupplierEvent {
  final SupplierModel supplier;
  const SupplierAddRequested({required this.supplier});
  @override
  List<Object?> get props => [supplier];
}

class SupplierUpdateRequested extends SupplierEvent {
  final SupplierModel supplier;
  const SupplierUpdateRequested({required this.supplier});
  @override
  List<Object?> get props => [supplier];
}

class SupplierDeleteRequested extends SupplierEvent {
  final String supplierId;
  const SupplierDeleteRequested({required this.supplierId});
  @override
  List<Object?> get props => [supplierId];
}

class SupplierSearchRequested extends SupplierEvent {
  final String query;
  const SupplierSearchRequested({required this.query});
  @override
  List<Object?> get props => [query];
}
