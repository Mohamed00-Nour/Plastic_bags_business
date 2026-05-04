import 'package:equatable/equatable.dart';
import '../../../data/models/raw_material_model.dart';

abstract class RawMaterialState extends Equatable {
  const RawMaterialState();
  @override
  List<Object?> get props => [];
}

class RawMaterialInitial extends RawMaterialState {}

class RawMaterialLoading extends RawMaterialState {}

class RawMaterialLoaded extends RawMaterialState {
  final List<RawMaterialModel> all;
  final List<RawMaterialModel> filtered;
  final String searchQuery;

  const RawMaterialLoaded({
    required this.all,
    required this.filtered,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [all, filtered, searchQuery];
}

class RawMaterialOperationSuccess extends RawMaterialState {
  final String message;
  const RawMaterialOperationSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class RawMaterialError extends RawMaterialState {
  final String message;
  const RawMaterialError({required this.message});
  @override
  List<Object?> get props => [message];
}
