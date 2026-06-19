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
    on<RawMaterialStockInRequested>(_onStockIn);
    on<RawMaterialQuantityAddRequested>(_onQuantityAdd);
    on<RawMaterialQuantityReduceRequested>(_onQuantityReduce);
  }

  static double weightedAveragePrice({
    required double currentStock,
    required double currentPricePerKg,
    required double quantityKg,
    required double purchasePricePerKg,
  }) {
    final totalQty = currentStock + quantityKg;
    if (totalQty <= 0) return purchasePricePerKg;
    return (currentStock * currentPricePerKg +
            quantityKg * purchasePricePerKg) /
        totalQty;
  }

  Future<void> _performStockIn({
    required String materialId,
    required String materialName,
    required double quantityKg,
    required double purchasePricePerKg,
    required double currentStock,
    required double currentPricePerKg,
    String? note,
    String? supplierId,
    String? supplierName,
  }) async {
    final newAvg = weightedAveragePrice(
      currentStock: currentStock,
      currentPricePerKg: currentPricePerKg,
      quantityKg: quantityKg,
      purchasePricePerKg: purchasePricePerKg,
    );

    await _repository.stockIn(materialId, quantityKg, newAvg);

    if (supplierId != null || supplierName != null) {
      final material = await _repository.getById(materialId);
      if (material != null) {
        await _repository.update(material.copyWith(
          supplierId: supplierId ?? material.supplierId,
          supplierName: supplierName ?? material.supplierName,
        ));
      }
    }

    if (_stockLogRepository != null) {
      final log = MaterialStockLogModel(
        id: const Uuid().v4(),
        materialId: materialId,
        materialName: materialName,
        type: MaterialStockChangeType.addition,
        quantityKg: quantityKg,
        stockBefore: currentStock,
        stockAfter: currentStock + quantityKg,
        pricePerKg: purchasePricePerKg,
        avgPriceAfter: newAvg,
        note: note,
        createdAt: DateTime.now(),
      );
      await _stockLogRepository!.add(log);
    }
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
      final existing =
          await _repository.findByName(event.material.name);
      if (existing != null) {
        emit(const RawMaterialError(
            message:
                'الخامة موجودة بالفعل — استخدم "خامة موجودة" لإضافة كمية'));
        return;
      }
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

  Future<void> _onStockIn(RawMaterialStockInRequested event,
      Emitter<RawMaterialState> emit) async {
    try {
      if (event.quantityKg <= 0 || event.purchasePricePerKg <= 0) {
        emit(const RawMaterialError(
            message: 'أدخل كمية وسعر صحيحين'));
        return;
      }
      await _performStockIn(
        materialId: event.materialId,
        materialName: event.materialName,
        quantityKg: event.quantityKg,
        purchasePricePerKg: event.purchasePricePerKg,
        currentStock: event.currentStock,
        currentPricePerKg: event.currentPricePerKg,
        note: event.note,
        supplierId: event.supplierId,
        supplierName: event.supplierName,
      );
      emit(const RawMaterialOperationSuccess(message: 'تم إضافة الكمية'));
    } catch (e) {
      emit(RawMaterialError(message: e.toString()));
    }
  }

  Future<void> _onQuantityAdd(RawMaterialQuantityAddRequested event,
      Emitter<RawMaterialState> emit) async {
    try {
      if (event.quantityKg <= 0 || event.purchasePricePerKg <= 0) {
        emit(const RawMaterialError(
            message: 'أدخل كمية وسعر صحيحين'));
        return;
      }
      await _performStockIn(
        materialId: event.materialId,
        materialName: event.materialName,
        quantityKg: event.quantityKg,
        purchasePricePerKg: event.purchasePricePerKg,
        currentStock: event.currentStock,
        currentPricePerKg: event.currentPricePerKg,
        note: event.note,
        supplierId: event.supplierId,
        supplierName: event.supplierName,
      );
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
        await _stockLogRepository!.add(log);
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
