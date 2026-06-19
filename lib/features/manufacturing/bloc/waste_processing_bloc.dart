import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/damaged_inventory_model.dart';
import '../../../data/models/material_supplier_model.dart';
import '../../../data/models/raw_material_model.dart';
import '../../../data/models/waste_machine_model.dart';
import '../../../data/models/waste_processing_run_model.dart';
import '../../../data/repositories/damaged_inventory_repository.dart';
import '../../../data/repositories/material_supplier_repository.dart';
import '../../../data/repositories/waste_machine_repository.dart';
import '../../../data/repositories/waste_processing_repository.dart';
import '../../../data/repositories/raw_material_repository.dart';
import 'waste_processing_event.dart';
import 'waste_processing_state.dart';

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
  final MaterialSupplierRepository _supplierRepo;
  final DamagedInventoryRepository _damagedRepo;

  StreamSubscription? _machinesSub;
  StreamSubscription? _runsSub;
  List<WasteMachineModel> _machines = [];
  List<WasteProcessingRunModel> _runs = [];

  WasteProcessingBloc({
    required WasteMachineRepository machineRepository,
    required WasteProcessingRepository processingRepository,
    required RawMaterialRepository materialRepository,
    required MaterialSupplierRepository supplierRepository,
    required DamagedInventoryRepository damagedRepository,
  })  : _machineRepo = machineRepository,
        _runRepo = processingRepository,
        _materialRepo = materialRepository,
        _supplierRepo = supplierRepository,
        _damagedRepo = damagedRepository,
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

  void _restoreLoaded(Emitter<WasteProcessingState> emit) {
    if (_machines.isEmpty && _runs.isEmpty) return;
    emit(WasteProcessingLoaded(machines: _machines, runs: _runs));
  }

  Future<void> _onLoad(WasteProcessingLoadRequested event,
      Emitter<WasteProcessingState> emit) async {
    emit(WasteProcessingLoading());
    await _machinesSub?.cancel();
    await _runsSub?.cancel();

    _machinesSub = _machineRepo.getAll().listen(
      (machines) {
        if (!isClosed) add(_MachinesReceived(machines));
      },
    );
    _runsSub = _runRepo.getAll().listen(
      (runs) {
        if (!isClosed) add(_RunsReceived(runs));
      },
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
      _restoreLoaded(emit);
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
      _restoreLoaded(emit);
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
      _restoreLoaded(emit);
    }
  }

  Future<void> _onAddRun(WasteRunAddRequested event,
      Emitter<WasteProcessingState> emit) async {
    try {
      await _runRepo.add(event.run);
      emit(const WasteProcessingOperationSuccess(
          message: 'تم إضافة تشغيلة الخرازة'));
    } catch (e) {
      emit(WasteProcessingError(message: e.toString()));
      _restoreLoaded(emit);
    }
  }

  Future<void> _onUpdateRun(WasteRunUpdateRequested event,
      Emitter<WasteProcessingState> emit) async {
    try {
      if (event.execute) {
        await _executeRun(event.run, emit);
        return;
      }
      await _runRepo.update(event.run);
      emit(const WasteProcessingOperationSuccess(
          message: 'تم تحديث تشغيلة الخرازة'));
    } catch (e) {
      emit(WasteProcessingError(message: e.toString()));
      _restoreLoaded(emit);
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
      _restoreLoaded(emit);
    }
  }

  Future<MaterialSupplierModel> _getOrCreateKharazaSupplier() async {
    final existing = await _supplierRepo.findByName(
        WasteProcessingRunModel.kharazaSupplierName);
    if (existing != null) return existing;

    final now = DateTime.now();
    final supplier = MaterialSupplierModel(
      id: const Uuid().v4(),
      name: WasteProcessingRunModel.kharazaSupplierName,
      phone: '',
      createdAt: now,
      updatedAt: now,
    );
    await _supplierRepo.add(supplier);
    return supplier;
  }

  Future<RawMaterialModel> _getOrCreateHeavyMaterial(
    WasteProcessingRunModel run,
    MaterialSupplierModel supplier,
  ) async {
    final existing = await _materialRepo.findByName(
        WasteProcessingRunModel.heavyMaterialName);
    if (existing != null) return existing;

    final now = DateTime.now();
    final material = RawMaterialModel(
      id: const Uuid().v4(),
      name: WasteProcessingRunModel.heavyMaterialName,
      type: WasteProcessingRunModel.heavyMaterialName,
      pricePerKg: run.costPerKg,
      quantityKg: 0,
      supplierId: supplier.id,
      supplierName: supplier.name,
      createdAt: now,
      updatedAt: now,
    );
    await _materialRepo.add(material);
    return material;
  }

  Future<void> _executeRun(
    WasteProcessingRunModel run,
    Emitter<WasteProcessingState> emit,
  ) async {
    if (run.outputKg == null || run.effectiveOutputKg <= 0) {
      emit(const WasteProcessingError(
          message: 'لا يمكن تنفيذ التشغيلة - أدخل كمية الخرج'));
      _restoreLoaded(emit);
      return;
    }
    if (run.inputKg <= 0) {
      emit(const WasteProcessingError(
          message: 'لا يمكن تنفيذ التشغيلة - أدخل كمية الدخول'));
      _restoreLoaded(emit);
      return;
    }
    if (run.isExecuted) {
      emit(const WasteProcessingError(
          message: 'تم تنفيذ هذه التشغيلة مسبقاً'));
      _restoreLoaded(emit);
      return;
    }

    final damagedTotal = await _damagedRepo.getTotalKg();
    if (damagedTotal + 0.001 < run.inputKg) {
      emit(WasteProcessingError(
          message:
              'مخزون الهالك غير كافٍ (المتاح: ${damagedTotal.toStringAsFixed(1)} كجم)'));
      _restoreLoaded(emit);
      return;
    }

    await _runRepo.update(run);

    await _damagedRepo.add(DamagedInventoryModel(
      id: const Uuid().v4(),
      wasteRunId: run.id,
      mixName: run.machineName,
      productName: 'خصم هالك - تشغيلة خرازة',
      damagedKg: run.inputKg,
      entryType: DamagedInventoryEntryType.deduction,
      date: run.date,
      createdAt: DateTime.now(),
    ));

    var executedRun = run.copyWith(status: WasteRunStatus.executed);

    if (run.resultType == WasteResultType.rawMaterial) {
      final supplier = await _getOrCreateKharazaSupplier();
      final heavy = await _getOrCreateHeavyMaterial(run, supplier);

      await _materialRepo.incrementQuantity(
          heavy.id, run.effectiveOutputKg);

      executedRun = executedRun.copyWith(
        resultMaterialId: heavy.id,
        resultMaterialName: heavy.name,
      );
    }

    await _runRepo.update(executedRun);
    await _runRepo.executeRun(run.id);
    emit(const WasteProcessingOperationSuccess(
        message: 'تم تنفيذ تشغيلة الخرازة'));
  }

  @override
  Future<void> close() {
    _machinesSub?.cancel();
    _runsSub?.cancel();
    return super.close();
  }
}
