import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/production_run_model.dart';
import '../../../data/repositories/production_run_repository.dart';
import 'production_run_event.dart';
import 'production_run_state.dart';

// Private internal event — defined in this file only
class _RunsReceived extends ProductionRunEvent {
  final List<ProductionRunModel> runs;
  const _RunsReceived(this.runs);
  @override
  List<Object?> get props => [runs];
}

class _RunsError extends ProductionRunEvent {
  final String message;
  const _RunsError(this.message);
  @override
  List<Object?> get props => [message];
}

class ProductionRunBloc
    extends Bloc<ProductionRunEvent, ProductionRunState> {
  final ProductionRunRepository _repository;
  StreamSubscription? _subscription;

  ProductionRunBloc({required ProductionRunRepository repository})
      : _repository = repository,
        super(ProductionRunInitial()) {
    on<ProductionRunLoadRequested>(_onLoad);
    on<_RunsReceived>(
        (event, emit) => emit(ProductionRunLoaded(runs: event.runs)));
    on<_RunsError>(
        (event, emit) => emit(ProductionRunError(message: event.message)));
    on<ProductionRunAddRequested>(_onAdd);
    on<ProductionRunUpdateRequested>(_onUpdate);
    on<ProductionRunDeleteRequested>(_onDelete);
  }

  Future<void> _onLoad(ProductionRunLoadRequested event,
      Emitter<ProductionRunState> emit) async {
    emit(ProductionRunLoading());
    await _subscription?.cancel();
    _subscription = _repository.getAll().listen(
      (runs) { if (!isClosed) add(_RunsReceived(runs)); },
      onError: (e) { if (!isClosed) add(_RunsError(e.toString())); },
    );
  }

  Future<void> _onAdd(ProductionRunAddRequested event,
      Emitter<ProductionRunState> emit) async {
    try {
      await _repository.add(event.run);
      emit(const ProductionRunOperationSuccess(
          message: 'تم إضافة التشغيلة'));
    } catch (e) {
      emit(ProductionRunError(message: e.toString()));
    }
  }

  Future<void> _onUpdate(ProductionRunUpdateRequested event,
      Emitter<ProductionRunState> emit) async {
    try {
      await _repository.update(event.run);
      emit(const ProductionRunOperationSuccess(
          message: 'تم تحديث التشغيلة'));
    } catch (e) {
      emit(ProductionRunError(message: e.toString()));
    }
  }

  Future<void> _onDelete(ProductionRunDeleteRequested event,
      Emitter<ProductionRunState> emit) async {
    try {
      await _repository.delete(event.id);
      emit(const ProductionRunOperationSuccess(
          message: 'تم حذف التشغيلة'));
    } catch (e) {
      emit(ProductionRunError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
