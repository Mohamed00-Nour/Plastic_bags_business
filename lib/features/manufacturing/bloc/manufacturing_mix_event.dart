import 'package:equatable/equatable.dart';
import '../../../data/models/manufacturing_mix_model.dart';

abstract class ManufacturingMixEvent extends Equatable {
  const ManufacturingMixEvent();
  @override
  List<Object?> get props => [];
}

class ManufacturingMixLoadRequested extends ManufacturingMixEvent {}

class ManufacturingMixSearchRequested extends ManufacturingMixEvent {
  final String query;
  const ManufacturingMixSearchRequested({required this.query});
  @override
  List<Object?> get props => [query];
}

class ManufacturingMixAddRequested extends ManufacturingMixEvent {
  final ManufacturingMixModel mix;
  const ManufacturingMixAddRequested({required this.mix});
  @override
  List<Object?> get props => [mix];
}

class ManufacturingMixUpdateRequested extends ManufacturingMixEvent {
  final ManufacturingMixModel mix;
  const ManufacturingMixUpdateRequested({required this.mix});
  @override
  List<Object?> get props => [mix];
}

class ManufacturingMixDeleteRequested extends ManufacturingMixEvent {
  final String id;
  const ManufacturingMixDeleteRequested({required this.id});
  @override
  List<Object?> get props => [id];
}
