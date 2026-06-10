import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/material_supplier_model.dart';
import '../../../data/repositories/material_supplier_repository.dart';
import 'material_supplier_event.dart';
import 'material_supplier_state.dart';

class _SuppliersReceived extends MaterialSupplierEvent {
  final List<MaterialSupplierModel> suppliers;
  const _SuppliersReceived(this.suppliers);
  @override
  List<Object?> get props => [suppliers];
}

class _SuppliersError extends MaterialSupplierEvent {
  final String message;
  const _SuppliersError(this.message);
  @override
  List<Object?> get props => [message];
}

class MaterialSupplierBloc
    extends Bloc<MaterialSupplierEvent, MaterialSupplierState> {
  final MaterialSupplierRepository _repository;
  StreamSubscription? _subscription;
  List<MaterialSupplierModel> _all = [];
  String _searchQuery = '';

  MaterialSupplierBloc({required MaterialSupplierRepository repository})
      : _repository = repository,
        super(MaterialSupplierInitial()) {
    on<MaterialSupplierLoadRequested>(_onLoad);
    on<_SuppliersReceived>(_onReceived);
    on<_SuppliersError>(
        (event, emit) => emit(MaterialSupplierError(message: event.message)));
    on<MaterialSupplierSearchRequested>(_onSearch);
    on<MaterialSupplierAddRequested>(_onAdd);
    on<MaterialSupplierUpdateRequested>(_onUpdate);
    on<MaterialSupplierDeleteRequested>(_onDelete);
  }

  Future<void> _onLoad(MaterialSupplierLoadRequested event,
      Emitter<MaterialSupplierState> emit) async {
    emit(MaterialSupplierLoading());
    await _subscription?.cancel();
    _subscription = _repository.getAll().listen(
      (suppliers) {
        if (!isClosed) add(_SuppliersReceived(suppliers));
      },
      onError: (e) {
        if (!isClosed) add(_SuppliersError(e.toString()));
      },
    );
  }

  void _onReceived(
      _SuppliersReceived event, Emitter<MaterialSupplierState> emit) {
    _all = event.suppliers;
    emit(MaterialSupplierLoaded(
      all: _all,
      filtered: _applySearch(_all, _searchQuery),
      searchQuery: _searchQuery,
    ));
  }

  void _onSearch(MaterialSupplierSearchRequested event,
      Emitter<MaterialSupplierState> emit) {
    _searchQuery = event.query;
    emit(MaterialSupplierLoaded(
      all: _all,
      filtered: _applySearch(_all, _searchQuery),
      searchQuery: _searchQuery,
    ));
  }

  List<MaterialSupplierModel> _applySearch(
      List<MaterialSupplierModel> list, String q) {
    if (q.isEmpty) return list;
    final lower = q.toLowerCase();
    return list
        .where((s) =>
            s.name.toLowerCase().contains(lower) ||
            s.phone.toLowerCase().contains(lower))
        .toList();
  }

  Future<void> _onAdd(MaterialSupplierAddRequested event,
      Emitter<MaterialSupplierState> emit) async {
    try {
      await _repository.add(event.supplier);
      emit(const MaterialSupplierOperationSuccess(
          message: 'تم إضافة المورد'));
    } catch (e) {
      emit(MaterialSupplierError(message: e.toString()));
    }
  }

  Future<void> _onUpdate(MaterialSupplierUpdateRequested event,
      Emitter<MaterialSupplierState> emit) async {
    try {
      await _repository.update(event.supplier);
      emit(const MaterialSupplierOperationSuccess(
          message: 'تم تحديث المورد'));
    } catch (e) {
      emit(MaterialSupplierError(message: e.toString()));
    }
  }

  Future<void> _onDelete(MaterialSupplierDeleteRequested event,
      Emitter<MaterialSupplierState> emit) async {
    try {
      await _repository.delete(event.id);
      emit(const MaterialSupplierOperationSuccess(
          message: 'تم حذف المورد'));
    } catch (e) {
      emit(MaterialSupplierError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
