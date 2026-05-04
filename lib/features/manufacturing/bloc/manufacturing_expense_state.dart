import 'package:equatable/equatable.dart';
import '../../../data/models/manufacturing_expense_model.dart';

abstract class ManufacturingExpenseState extends Equatable {
  const ManufacturingExpenseState();
  @override
  List<Object?> get props => [];
}

class ManufacturingExpenseInitial extends ManufacturingExpenseState {}

class ManufacturingExpenseLoading extends ManufacturingExpenseState {}

class ManufacturingExpenseLoaded extends ManufacturingExpenseState {
  final List<ManufacturingExpenseModel> expenses;

  const ManufacturingExpenseLoaded({required this.expenses});

  double get grandTotal =>
      expenses.fold(0, (s, e) => s + e.amount);

  Map<String, double> get totalByCategory {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  @override
  List<Object?> get props => [expenses];
}

class ManufacturingExpenseOperationSuccess extends ManufacturingExpenseState {
  final String message;
  const ManufacturingExpenseOperationSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class ManufacturingExpenseError extends ManufacturingExpenseState {
  final String message;
  const ManufacturingExpenseError({required this.message});
  @override
  List<Object?> get props => [message];
}
