import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/waste_machine_model.dart';
import '../../../data/models/waste_processing_run_model.dart';
import '../../../data/repositories/waste_machine_repository.dart';
import '../../../data/repositories/waste_processing_repository.dart';
import '../../../data/repositories/raw_material_repository.dart';
import '../../../data/models/raw_material_model.dart';
import 'waste_processing_event.dart';
import 'waste_processing_state.dart';

// Private internal events
class _MachinesReceived extends WasteProcessingEvent {
  final List<WasteMachineModel> machines;
  const _MachinesReceived(this.machines);
  @override
  List<Object?> get props => [machines];
}

class _RunsReceived extends WasteProcessingEvent {
  final List<WasteProcessingRunModel> runs;
  const _RunsReceived(this.runs);
  @override
  List<Object?> get props => [runs];
}

class WasteProcessingBloc
    extends Bloc<WasteProcessingEvent, WasteProcessingState> {
  final WasteMachineRepository _machineRepo;
  final WasteProcessingRepository _runRepo;
  final RawMaterialRepository _materialRepo;

  StreamSubscription? _machinesSub;
  StreamSubscription? _runsSub;
  List<WasteMachineModel> _machines = [];
  List<WasteProcessingRunModel> _runs = [];

  WasteProcessingBloc({
    required WasteMachineRepository machineRepository,
    required WasteProcessingRepository processingRepository,
    required RawMaterialRepository materialRepository,
  })  : _machineRepo = machineRepository,
        _runRepo = processingRepository,
        _materialRepo = materialRepository,
        super(WasteProcessingInitial()) {
    on<WasteProcessingLoadRequested>(_onLoad);
    on<_MachinesReceived>((event, emit) {
      _machines = event.machines;
      emit(WasteProcessingLoaded(machines: _machines, runs: _runs));
    });
    on<_RunsReceived>((event, emit) {
      _runs = event.runs;
      emit(WasteProcessingLoaded(machines: _machines, runs: _runs));
    });
    on<WasteMachineAddRequested>(_onAddMachine);
    on<WasteMachineUpdateRequested>(_onUpdateMachine);
    on<WasteMachineDeleteRequested>(_onDeleteMachine);
    on<WasteRunAddRequested>(_onAddRun);
    on<WasteRunUpdateRequested>(_onUpdateRun);
    on<WasteRunDeleteRequested>(_onDeleteRun);
  }

  Future<void> _onLoad(WasteProcessingLoadRequested event,
      Emitter<WasteProcessingState> emit) async {
    emit(WasteProcessingLoading());
    await _machinesSub?.cancel();
    await _runsSub?.cancel();

    _machinesSub = _machineRepo.getAll().listen(
      (machines) { if (!isClosed) add(_MachinesReceived(machines)); },
    );
    _runsSub = _runRepo.getAll().listen(
      (runs) { if (!isClosed) add(_RunsReceived(runs)); },
    );
  }

  Future<void> _onAddMachine(WasteMachineAddRequested event,
      Emitter<WasteProcessingState> emit) async {
    try {
      await _machineRepo.add(event.machine);
      emit(const WasteProcessingOperationSuccess(
          message: 'تم إضافة الماكينة'));
    } catch (e) {
      emit(WasteProcessingError(message: e.toString()));
    }
  }

  Future<void> _onUpdateMachine(WasteMachineUpdateRequested event,
      Emitter<WasteProcessingState> emit) async {
    try {
      await _machineRepo.update(event.machine);
      emit(const WasteProcessingOperationSuccess(
          message: 'تم تحديث الماكينة'));
    } catch (e) {
      emit(WasteProcessingError(message: e.toString()));
    }
  }

  Future<void> _onDeleteMachine(WasteMachineDeleteRequested event,
      Emitter<WasteProcessingState> emit) async {
    try {
      await _machineRepo.delete(event.id);
      emit(const WasteProcessingOperationSuccess(
          message: 'تم حذف الماكينة'));
    } catch (e) {
      emit(WasteProcessingError(message: e.toString()));
    }
  }

  Future<void> _onAddRun(WasteRunAddRequested event,
      Emitter<WasteProcessingState> emit) async {
    try {
      await _runRepo.add(event.run);
      // If result is rawMaterial, create a new raw material record
      if (event.run.resultType == WasteResultType.rawMaterial &&
          event.run.outputKg > 0) {
        final now = DateTime.now();
        final newMaterial = RawMaterialModel(
          id: event.run.resultMaterialId ??
              '${event.run.id}_material',
          name: event.run.resultMaterialName ??
              'هالك مخروز - ${event.run.machineName}',
          type: 'هالك مخروز',
          pricePerKg: event.run.costPerKg,
          unit: 'kg',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        await _materialRepo.add(newMaterial);
      }
      emit(const WasteProcessingOperationSuccess(
          message: 'تم إضافة تشغيلة الخرازة'));
    } catch (e) {
      emit(WasteProcessingError(message: e.toString()));
    }
  }

  Future<void> _onUpdateRun(WasteRunUpdateRequested event,
      Emitter<WasteProcessingState> emit) async {
    try {
      await _runRepo.update(event.run);
      emit(const WasteProcessingOperationSuccess(
          message: 'تم تحديث تشغيلة الخرازة'));
    } catch (e) {
      emit(WasteProcessingError(message: e.toString()));
    }
  }

  Future<void> _onDeleteRun(WasteRunDeleteRequested event,
      Emitter<WasteProcessingState> emit) async {
    try {
      await _runRepo.delete(event.id);
      emit(const WasteProcessingOperationSuccess(
          message: 'تم حذف تشغيلة الخرازة'));
    } catch (e) {
      emit(WasteProcessingError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _machinesSub?.cancel();
    _runsSub?.cancel();
    return super.close();
  }
}
