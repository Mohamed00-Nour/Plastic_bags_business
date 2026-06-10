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

class ProductionRunExecuteRequested extends ProductionRunEvent {
  final ProductionRunModel run;
  const ProductionRunExecuteRequested({required this.run});
  @override
  List<Object?> get props => [run];
}

enum RunFilterPeriod { all, today, thisWeek, thisMonth, custom }

class ProductionRunFilterRequested extends ProductionRunEvent {
  final RunFilterPeriod period;
  final DateTime? customStart;
  final DateTime? customEnd;
  const ProductionRunFilterRequested({
    required this.period,
    this.customStart,
    this.customEnd,
  });
  @override
  List<Object?> get props => [period, customStart, customEnd];
}
