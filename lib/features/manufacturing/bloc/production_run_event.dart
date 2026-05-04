import 'package:equatable/equatable.dart';
import '../../../data/models/production_run_model.dart';

abstract class ProductionRunEvent extends Equatable {
  const ProductionRunEvent();
  @override
  List<Object?> get props => [];
}

class ProductionRunLoadRequested extends ProductionRunEvent {}

class ProductionRunAddRequested extends ProductionRunEvent {
  final ProductionRunModel run;
  const ProductionRunAddRequested({required this.run});
  @override
  List<Object?> get props => [run];
}

class ProductionRunUpdateRequested extends ProductionRunEvent {
  final ProductionRunModel run;
  const ProductionRunUpdateRequested({required this.run});
  @override
  List<Object?> get props => [run];
}

class ProductionRunDeleteRequested extends ProductionRunEvent {
  final String id;
  const ProductionRunDeleteRequested({required this.id});
  @override
  List<Object?> get props => [id];
}
