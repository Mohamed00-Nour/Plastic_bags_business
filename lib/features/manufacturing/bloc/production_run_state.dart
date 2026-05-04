import 'package:equatable/equatable.dart';
import '../../../data/models/production_run_model.dart';

abstract class ProductionRunState extends Equatable {
  const ProductionRunState();
  @override
  List<Object?> get props => [];
}

class ProductionRunInitial extends ProductionRunState {}

class ProductionRunLoading extends ProductionRunState {}

class ProductionRunLoaded extends ProductionRunState {
  final List<ProductionRunModel> runs;

  const ProductionRunLoaded({required this.runs});

  double get totalOutput =>
      runs.fold(0, (s, r) => s + r.outputKg);
  double get totalWaste =>
      runs.fold(0, (s, r) => s + r.wasteKg);
  double get totalCost =>
      runs.fold(0, (s, r) => s + r.totalCost);
  double get averageCostPerKg {
    if (totalOutput == 0) return 0;
    return totalCost / totalOutput;
  }

  @override
  List<Object?> get props => [runs];
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
