import 'package:equatable/equatable.dart';
import '../../../data/models/waste_machine_model.dart';
import '../../../data/models/waste_processing_run_model.dart';

abstract class WasteProcessingState extends Equatable {
  const WasteProcessingState();
  @override
  List<Object?> get props => [];
}

class WasteProcessingInitial extends WasteProcessingState {}

class WasteProcessingLoading extends WasteProcessingState {}

class WasteProcessingLoaded extends WasteProcessingState {
  final List<WasteMachineModel> machines;
  final List<WasteProcessingRunModel> runs;

  const WasteProcessingLoaded({
    required this.machines,
    required this.runs,
  });

  double get totalInput => runs.fold(0, (s, r) => s + r.inputKg);
  double get totalOutput => runs.fold(0, (s, r) => s + r.outputKg);
  double get totalLoss => runs.fold(0, (s, r) => s + r.lossKg);
  double get totalCost => runs.fold(0, (s, r) => s + r.totalCost);

  @override
  List<Object?> get props => [machines, runs];
}

class WasteProcessingOperationSuccess extends WasteProcessingState {
  final String message;
  const WasteProcessingOperationSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class WasteProcessingError extends WasteProcessingState {
  final String message;
  const WasteProcessingError({required this.message});
  @override
  List<Object?> get props => [message];
}
