import 'package:equatable/equatable.dart';
import '../../../data/models/manufacturing_mix_model.dart';

abstract class ManufacturingMixState extends Equatable {
  const ManufacturingMixState();
  @override
  List<Object?> get props => [];
}

class ManufacturingMixInitial extends ManufacturingMixState {}

class ManufacturingMixLoading extends ManufacturingMixState {}

class ManufacturingMixLoaded extends ManufacturingMixState {
  final List<ManufacturingMixModel> all;
  final List<ManufacturingMixModel> filtered;
  final String searchQuery;

  const ManufacturingMixLoaded({
    required this.all,
    required this.filtered,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [all, filtered, searchQuery];
}

class ManufacturingMixOperationSuccess extends ManufacturingMixState {
  final String message;
  const ManufacturingMixOperationSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class ManufacturingMixError extends ManufacturingMixState {
  final String message;
  const ManufacturingMixError({required this.message});
  @override
  List<Object?> get props => [message];
}
