import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/raw_material_model.dart';
import '../../../data/models/material_stock_log_model.dart';
import '../../../data/repositories/raw_material_repository.dart';
import '../../../data/repositories/material_stock_log_repository.dart';
import 'raw_material_event.dart';
import 'raw_material_state.dart';

class RawMaterialBloc extends Bloc<RawMaterialEvent, RawMaterialState> {
  final RawMaterialRepository _repository;
  final MaterialStockLogRepository? _stockLogRepository;
  StreamSubscription? _subscription;
  List<RawMaterialModel> _all = [];

  RawMaterialBloc({
    required RawMaterialRepository repository,
    MaterialStockLogRepository? stockLogRepository,
  })  : _repository = repository,
        _stockLogRepository = stockLogRepository,
        super(RawMaterialInitial()) {
    on<RawMaterialLoadRequested>(_onLoad);
    on<RawMaterialSearchRequested>(_onSearch);
    on<RawMaterialAddRequested>(_onAdd);
    on<RawMaterialUpdateRequested>(_onUpdate);
    on<RawMaterialDeleteRequested>(_onDelete);
    on<RawMaterialQuantityAddRequested>(_onQuantityAdd);
    on<RawMaterialQuantityReduceRequested>(_onQuantityReduce);
  }

  Future<void> _onLoad(
      RawMaterialLoadRequested event, Emitter<RawMaterialState> emit) async {
    emit(RawMaterialLoading());
    await _subscription?.cancel();
    _subscription = _repository.getAll().listen(
      (materials) {
        _all = materials;
        add(RawMaterialSearchRequested(query: ''));
      },
      onError: (e) => add(RawMaterialSearchRequested(query: '')),
    );
  }

  void _onSearch(
      RawMaterialSearchRequested event, Emitter<RawMaterialState> emit) {
    final q = event.query.toLowerCase();
    final filtered = q.isEmpty
        ? _all
        : _all
            .where((m) =>
                m.name.toLowerCase().contains(q) ||
                m.type.toLowerCase().contains(q))
            .toList();
    emit(RawMaterialLoaded(
        all: _all, filtered: filtered, searchQuery: event.query));
  }

  Future<void> _onAdd(
      RawMaterialAddRequested event, Emitter<RawMaterialState> emit) async {
    try {
      await _repository.add(event.material);
      emit(const RawMaterialOperationSuccess(message: 'تم إضافة الخامة'));
    } catch (e) {
      emit(RawMaterialError(message: e.toString()));
    }
  }

  Future<void> _onUpdate(RawMaterialUpdateRequested event,
      Emitter<RawMaterialState> emit) async {
    try {
      await _repository.update(event.material);
      emit(const RawMaterialOperationSuccess(message: 'تم تحديث الخامة'));
    } catch (e) {
      emit(RawMaterialError(message: e.toString()));
    }
  }

  Future<void> _onDelete(RawMaterialDeleteRequested event,
      Emitter<RawMaterialState> emit) async {
    try {
      await _repository.delete(event.id);
      emit(const RawMaterialOperationSuccess(message: 'تم حذف الخامة'));
    } catch (e) {
      emit(RawMaterialError(message: e.toString()));
    }
  }

  Future<void> _onQuantityAdd(RawMaterialQuantityAddRequested event,
      Emitter<RawMaterialState> emit) async {
    try {
      await _repository.incrementQuantity(event.materialId, event.quantityKg);
      if (_stockLogRepository != null) {
        final log = MaterialStockLogModel(
          id: const Uuid().v4(),
          materialId: event.materialId,
          materialName: event.materialName,
          type: MaterialStockChangeType.addition,
          quantityKg: event.quantityKg,
          stockBefore: event.currentStock,
          stockAfter: event.currentStock + event.quantityKg,
          note: event.note,
          createdAt: DateTime.now(),
        );
        await _stockLogRepository.add(log);
      }
      emit(const RawMaterialOperationSuccess(message: 'تم إضافة الكمية'));
    } catch (e) {
      emit(RawMaterialError(message: e.toString()));
    }
  }

  Future<void> _onQuantityReduce(RawMaterialQuantityReduceRequested event,
      Emitter<RawMaterialState> emit) async {
    try {
      await _repository.decrementQuantity(event.materialId, event.quantityKg);
      if (_stockLogRepository != null) {
        final log = MaterialStockLogModel(
          id: const Uuid().v4(),
          materialId: event.materialId,
          materialName: event.materialName,
          type: MaterialStockChangeType.reduction,
          quantityKg: event.quantityKg,
          stockBefore: event.currentStock,
          stockAfter: event.currentStock - event.quantityKg,
          note: event.note,
          createdAt: DateTime.now(),
        );
        await _stockLogRepository.add(log);
      }
      emit(const RawMaterialOperationSuccess(message: 'تم خصم الكمية'));
    } catch (e) {
      emit(RawMaterialError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
