import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/manufacturing_mix_model.dart';
import '../../../data/repositories/manufacturing_mix_repository.dart';
import 'manufacturing_mix_event.dart';
import 'manufacturing_mix_state.dart';

class ManufacturingMixBloc
    extends Bloc<ManufacturingMixEvent, ManufacturingMixState> {
  final ManufacturingMixRepository _repository;
  StreamSubscription? _subscription;
  List<ManufacturingMixModel> _all = [];

  ManufacturingMixBloc({required ManufacturingMixRepository repository})
      : _repository = repository,
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
      await _repository.add(event.mix);
      emit(const ManufacturingMixOperationSuccess(message: 'تم إضافة الخلطة'));
    } catch (e) {
      emit(ManufacturingMixError(message: e.toString()));
    }
  }

  Future<void> _onUpdate(ManufacturingMixUpdateRequested event,
      Emitter<ManufacturingMixState> emit) async {
    try {
      await _repository.update(event.mix);
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

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
