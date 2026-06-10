import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/manufacturing_mix_model.dart';
import '../../../data/repositories/manufacturing_mix_repository.dart';
import '../../../data/repositories/raw_material_repository.dart';
import 'manufacturing_mix_event.dart';
import 'manufacturing_mix_state.dart';

class ManufacturingMixBloc
    extends Bloc<ManufacturingMixEvent, ManufacturingMixState> {
  final ManufacturingMixRepository _repository;
  final RawMaterialRepository? _materialRepository;
  StreamSubscription? _subscription;
  List<ManufacturingMixModel> _all = [];

  ManufacturingMixBloc({
    required ManufacturingMixRepository repository,
    RawMaterialRepository? materialRepository,
  })  : _repository = repository,
        _materialRepository = materialRepository,
        super(ManufacturingMixInitial()) {
    on<ManufacturingMixLoadRequested>(_onLoad);
    on<ManufacturingMixSearchRequested>(_onSearch);
    on<ManufacturingMixAddRequested>(_onAdd);
    on<ManufacturingMixUpdateRequested>(_onUpdate);
    on<ManufacturingMixDeleteRequested>(_onDelete);
  }

  Future<void> _onLoad(ManufacturingMixLoadRequested event,
      Emitter<ManufacturingMixState> emit) async {
    emit(ManufacturingMixLoading());
    await _subscription?.cancel();
    _subscription = _repository.getAll().listen((mixes) {
      _all = mixes;
      add(ManufacturingMixSearchRequested(query: ''));
    });
  }

  void _onSearch(ManufacturingMixSearchRequested event,
      Emitter<ManufacturingMixState> emit) {
    final q = event.query.toLowerCase();
    final filtered = q.isEmpty
        ? _all
        : _all
            .where((m) =>
                m.name.toLowerCase().contains(q) ||
                m.productName.toLowerCase().contains(q))
            .toList();
    emit(ManufacturingMixLoaded(
        all: _all, filtered: filtered, searchQuery: event.query));
  }

  Future<void> _onAdd(ManufacturingMixAddRequested event,
      Emitter<ManufacturingMixState> emit) async {
    try {
      // Combine duplicate materials by summing their quantities
      final merged = _mergeDuplicateComponents(event.mix.components);
      final mix = ManufacturingMixModel(
        id: event.mix.id,
        name: event.mix.name,
        productName: event.mix.productName,
        components: merged,
        isActive: event.mix.isActive,
        createdAt: event.mix.createdAt,
        updatedAt: event.mix.updatedAt,
      );

      await _repository.add(mix);

      // Deduct material quantities used in the mix
      if (_materialRepository != null) {
        for (final comp in merged) {
          if (comp.quantityKg > 0) {
            await _materialRepository.decrementQuantity(
                comp.materialId, comp.quantityKg);
          }
        }
      }

      emit(const ManufacturingMixOperationSuccess(message: 'تم إضافة الخلطة'));
    } catch (e) {
      emit(ManufacturingMixError(message: e.toString()));
    }
  }

  Future<void> _onUpdate(ManufacturingMixUpdateRequested event,
      Emitter<ManufacturingMixState> emit) async {
    try {
      // Combine duplicate materials on update too
      final merged = _mergeDuplicateComponents(event.mix.components);
      final mix = ManufacturingMixModel(
        id: event.mix.id,
        name: event.mix.name,
        productName: event.mix.productName,
        components: merged,
        isActive: event.mix.isActive,
        createdAt: event.mix.createdAt,
        updatedAt: event.mix.updatedAt,
      );
      await _repository.update(mix);
      emit(const ManufacturingMixOperationSuccess(message: 'تم تحديث الخلطة'));
    } catch (e) {
      emit(ManufacturingMixError(message: e.toString()));
    }
  }

  Future<void> _onDelete(ManufacturingMixDeleteRequested event,
      Emitter<ManufacturingMixState> emit) async {
    try {
      await _repository.delete(event.id);
      emit(const ManufacturingMixOperationSuccess(message: 'تم حذف الخلطة'));
    } catch (e) {
      emit(ManufacturingMixError(message: e.toString()));
    }
  }

  List<MixComponent> _mergeDuplicateComponents(List<MixComponent> components) {
    final map = <String, MixComponent>{};
    for (final comp in components) {
      if (map.containsKey(comp.materialId)) {
        final existing = map[comp.materialId]!;
        map[comp.materialId] = existing.copyWith(
          quantityKg: existing.quantityKg + comp.quantityKg,
        );
      } else {
        map[comp.materialId] = comp;
      }
    }
    return map.values.toList();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
