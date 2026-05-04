import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/supplier_model_new.dart';
import '../../../data/repositories/supplier_repository.dart';
import 'supplier_event.dart';
import 'supplier_state.dart';

class SupplierBloc extends Bloc<SupplierEvent, SupplierState> {
  final SupplierRepository _supplierRepository;
  StreamSubscription? _subscription;
  List<SupplierModel> _allSuppliers = [];

  SupplierBloc({required SupplierRepository supplierRepository})
      : _supplierRepository = supplierRepository,
        super(SupplierInitial()) {
    on<SupplierLoadRequested>(_onLoad);
    on<SupplierAddRequested>(_onAdd);
    on<SupplierUpdateRequested>(_onUpdate);
    on<SupplierDeleteRequested>(_onDelete);
    on<SupplierSearchRequested>(_onSearch);
  }

  Future<void> _onLoad(
    SupplierLoadRequested event,
    Emitter<SupplierState> emit,
  ) async {
    emit(SupplierLoading());
    await _subscription?.cancel();
    _subscription = _supplierRepository.getSuppliers().listen(
      (suppliers) {
        _allSuppliers = suppliers;
        if (!isClosed) {
          add(const SupplierSearchRequested(query: ''));
        }
      },
      onError: (error) {
        if (!isClosed) {
          emit(SupplierError(message: error.toString()));
        }
      },
    );
  }

  void _onSearch(
    SupplierSearchRequested event,
    Emitter<SupplierState> emit,
  ) {
    final query = event.query.toLowerCase();
    final filtered = query.isEmpty
        ? _allSuppliers
        : _allSuppliers
            .where((s) =>
                s.name.toLowerCase().contains(query) ||
                s.phone.contains(query))
            .toList();
    emit(SupplierLoaded(
      suppliers: _allSuppliers,
      filteredSuppliers: filtered,
      searchQuery: event.query,
    ));
  }

  Future<void> _onAdd(
    SupplierAddRequested event,
    Emitter<SupplierState> emit,
  ) async {
    try {
      await _supplierRepository.addSupplier(event.supplier);
      emit(const SupplierOperationSuccess(
          message: 'Supplier added successfully'));
    } catch (e) {
      emit(SupplierError(message: e.toString()));
    }
  }

  Future<void> _onUpdate(
    SupplierUpdateRequested event,
    Emitter<SupplierState> emit,
  ) async {
    try {
      await _supplierRepository.updateSupplier(event.supplier);
      emit(const SupplierOperationSuccess(
          message: 'Supplier updated successfully'));
    } catch (e) {
      emit(SupplierError(message: e.toString()));
    }
  }

  Future<void> _onDelete(
    SupplierDeleteRequested event,
    Emitter<SupplierState> emit,
  ) async {
    try {
      await _supplierRepository.deleteSupplier(event.supplierId);
      emit(const SupplierOperationSuccess(
          message: 'Supplier deleted successfully'));
    } catch (e) {
      emit(SupplierError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
