import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/damaged_inventory_model.dart';
import '../../../data/models/production_run_model.dart';
import '../../../data/repositories/damaged_inventory_repository.dart';
import '../../../data/repositories/production_run_repository.dart';
import 'production_run_event.dart';
import 'production_run_state.dart';

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
  final DamagedInventoryRepository? _damagedRepository;
  StreamSubscription? _subscription;
  List<ProductionRunModel> _allRuns = [];
  RunFilterPeriod _activePeriod = RunFilterPeriod.all;
  DateTime? _customStart;
  DateTime? _customEnd;

  ProductionRunBloc({
    required ProductionRunRepository repository,
    DamagedInventoryRepository? damagedRepository,
  })  : _repository = repository,
        _damagedRepository = damagedRepository,
        super(ProductionRunInitial()) {
    on<ProductionRunLoadRequested>(_onLoad);
    on<_RunsReceived>(_onReceived);
    on<_RunsError>(
        (event, emit) => emit(ProductionRunError(message: event.message)));
    on<ProductionRunAddRequested>(_onAdd);
    on<ProductionRunUpdateRequested>(_onUpdate);
    on<ProductionRunDeleteRequested>(_onDelete);
    on<ProductionRunExecuteRequested>(_onExecute);
    on<ProductionRunFilterRequested>(_onFilter);
  }

  Future<void> _onLoad(ProductionRunLoadRequested event,
      Emitter<ProductionRunState> emit) async {
    emit(ProductionRunLoading());
    await _subscription?.cancel();
    _subscription = _repository.getAll().listen(
      (runs) {
        if (!isClosed) add(_RunsReceived(runs));
      },
      onError: (e) {
        if (!isClosed) add(_RunsError(e.toString()));
      },
    );
  }

  void _onReceived(_RunsReceived event, Emitter<ProductionRunState> emit) {
    _allRuns = event.runs;
    emit(ProductionRunLoaded(
      runs: _allRuns,
      filteredRuns: _applyFilter(_allRuns),
      activePeriod: _activePeriod,
      customStart: _customStart,
      customEnd: _customEnd,
    ));
  }

  void _onFilter(ProductionRunFilterRequested event,
      Emitter<ProductionRunState> emit) {
    _activePeriod = event.period;
    _customStart = event.customStart;
    _customEnd = event.customEnd;
    emit(ProductionRunLoaded(
      runs: _allRuns,
      filteredRuns: _applyFilter(_allRuns),
      activePeriod: _activePeriod,
      customStart: _customStart,
      customEnd: _customEnd,
    ));
  }

  List<ProductionRunModel> _applyFilter(List<ProductionRunModel> runs) {
    final now = DateTime.now();
    switch (_activePeriod) {
      case RunFilterPeriod.all:
        return runs;
      case RunFilterPeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        return runs.where((r) =>
            r.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            r.date.isBefore(end)).toList();
      case RunFilterPeriod.thisWeek:
        final weekDay = now.weekday;
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: weekDay - 1));
        final end = start.add(const Duration(days: 7));
        return runs.where((r) =>
            r.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            r.date.isBefore(end)).toList();
      case RunFilterPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return runs.where((r) =>
            r.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            r.date.isBefore(end)).toList();
      case RunFilterPeriod.custom:
        if (_customStart == null || _customEnd == null) return runs;
        return runs.where((r) =>
            r.date.isAfter(
                _customStart!.subtract(const Duration(seconds: 1))) &&
            r.date.isBefore(
                _customEnd!.add(const Duration(days: 1)))).toList();
    }
  }

  void _restoreLoaded(Emitter<ProductionRunState> emit) {
    if (_allRuns.isEmpty) return;
    emit(ProductionRunLoaded(
      runs: _allRuns,
      filteredRuns: _applyFilter(_allRuns),
      activePeriod: _activePeriod,
      customStart: _customStart,
      customEnd: _customEnd,
    ));
  }

  Future<void> _onAdd(ProductionRunAddRequested event,
      Emitter<ProductionRunState> emit) async {
    try {
      await _repository.add(event.run);
      emit(const ProductionRunOperationSuccess(
          message: 'تم إضافة التشغيلة'));
    } catch (e) {
      emit(ProductionRunError(message: e.toString()));
      _restoreLoaded(emit);
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
      _restoreLoaded(emit);
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
      _restoreLoaded(emit);
    }
  }

  Future<void> _onExecute(ProductionRunExecuteRequested event,
      Emitter<ProductionRunState> emit) async {
    try {
      final run = event.run;
      if (run.outputKg == null || run.effectiveOutputKg <= 0) {
        emit(const ProductionRunError(
            message: 'لا يمكن تنفيذ التشغيلة - أدخل كمية الخرج'));
        _restoreLoaded(emit);
        return;
      }
      if (run.isExecuted) {
        emit(const ProductionRunError(
            message: 'تم تنفيذ هذه التشغيلة مسبقاً'));
        _restoreLoaded(emit);
        return;
      }

      // Persist latest run data before executing
      await _repository.update(run);

      // Store damaged kg in damaged inventory
      final damaged = run.calculatedDamagedKg;
      if (damaged > 0 && _damagedRepository != null) {
        final entry = DamagedInventoryModel(
          id: const Uuid().v4(),
          productionRunId: run.id,
          mixId: run.mixId,
          mixName: run.mixName,
          productName: run.productName,
          damagedKg: damaged,
          date: run.date,
          createdAt: DateTime.now(),
        );
        await _damagedRepository.add(entry);
      }

      // Save the calculated damaged value and mark as executed
      await _repository.update(run.copyWith(
        damagedKg: damaged,
        status: ProductionRunStatus.executed,
      ));
      await _repository.executeRun(run.id);
      emit(const ProductionRunOperationSuccess(
          message: 'تم تنفيذ التشغيلة'));
    } catch (e) {
      emit(ProductionRunError(message: e.toString()));
      _restoreLoaded(emit);
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
