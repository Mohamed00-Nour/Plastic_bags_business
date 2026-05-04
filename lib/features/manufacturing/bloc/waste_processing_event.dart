import 'package:equatable/equatable.dart';
import '../../../data/models/waste_machine_model.dart';
import '../../../data/models/waste_processing_run_model.dart';

abstract class WasteProcessingEvent extends Equatable {
  const WasteProcessingEvent();
  @override
  List<Object?> get props => [];
}

class WasteProcessingLoadRequested extends WasteProcessingEvent {}

// Machines
class WasteMachineAddRequested extends WasteProcessingEvent {
  final WasteMachineModel machine;
  const WasteMachineAddRequested({required this.machine});
  @override
  List<Object?> get props => [machine];
}

class WasteMachineUpdateRequested extends WasteProcessingEvent {
  final WasteMachineModel machine;
  const WasteMachineUpdateRequested({required this.machine});
  @override
  List<Object?> get props => [machine];
}

class WasteMachineDeleteRequested extends WasteProcessingEvent {
  final String id;
  const WasteMachineDeleteRequested({required this.id});
  @override
  List<Object?> get props => [id];
}

// Processing runs
class WasteRunAddRequested extends WasteProcessingEvent {
  final WasteProcessingRunModel run;
  const WasteRunAddRequested({required this.run});
  @override
  List<Object?> get props => [run];
}

class WasteRunUpdateRequested extends WasteProcessingEvent {
  final WasteProcessingRunModel run;
  const WasteRunUpdateRequested({required this.run});
  @override
  List<Object?> get props => [run];
}

class WasteRunDeleteRequested extends WasteProcessingEvent {
  final String id;
  const WasteRunDeleteRequested({required this.id});
  @override
  List<Object?> get props => [id];
}
