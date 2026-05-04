import 'package:equatable/equatable.dart';
import '../../../data/models/manufacturing_expense_model.dart';

abstract class ManufacturingExpenseEvent extends Equatable {
  const ManufacturingExpenseEvent();
  @override
  List<Object?> get props => [];
}

class ManufacturingExpenseLoadRequested extends ManufacturingExpenseEvent {}

class ManufacturingExpenseAddRequested extends ManufacturingExpenseEvent {
  final ManufacturingExpenseModel expense;
  const ManufacturingExpenseAddRequested({required this.expense});
  @override
  List<Object?> get props => [expense];
}

class ManufacturingExpenseUpdateRequested extends ManufacturingExpenseEvent {
  final ManufacturingExpenseModel expense;
  const ManufacturingExpenseUpdateRequested({required this.expense});
  @override
  List<Object?> get props => [expense];
}

class ManufacturingExpenseDeleteRequested extends ManufacturingExpenseEvent {
  final String id;
  const ManufacturingExpenseDeleteRequested({required this.id});
  @override
  List<Object?> get props => [id];
}
