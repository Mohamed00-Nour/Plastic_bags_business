import 'package:equatable/equatable.dart';
import '../../../data/models/production_run_model.dart';
import 'production_run_event.dart';

abstract class ProductionRunState extends Equatable {
  const ProductionRunState();
  @override
  List<Object?> get props => [];
}

class ProductionRunInitial extends ProductionRunState {}

class ProductionRunLoading extends ProductionRunState {}

class ProductionRunLoaded extends ProductionRunState {
  final List<ProductionRunModel> runs;
  final List<ProductionRunModel> filteredRuns;
  final RunFilterPeriod activePeriod;
  final DateTime? customStart;
  final DateTime? customEnd;

  const ProductionRunLoaded({
    required this.runs,
    List<ProductionRunModel>? filteredRuns,
    this.activePeriod = RunFilterPeriod.all,
    this.customStart,
    this.customEnd,
  }) : filteredRuns = filteredRuns ?? runs;

  double get totalOutput =>
      filteredRuns.fold(0, (s, r) => s + r.effectiveOutputKg);
  double get totalWaste =>
      filteredRuns.fold(0, (s, r) => s + r.wasteKg);
  double get totalCost =>
      filteredRuns.fold(0, (s, r) => s + r.totalCost);
  double get averageCostPerKg {
    if (totalOutput == 0) return 0;
    return totalCost / totalOutput;
  }

  @override
  List<Object?> get props => [runs, filteredRuns, activePeriod];
}

class ProductionRunOperationSuccess extends ProductionRunState {
  final String message;
  const ProductionRunOperationSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class ProductionRunError extends ProductionRunState {
  final String message;
  const ProductionRunError({required this.message});
  @override
  List<Object?> get props => [message];
}
