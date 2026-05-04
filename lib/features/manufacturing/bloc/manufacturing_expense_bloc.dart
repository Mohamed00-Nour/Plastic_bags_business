import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/manufacturing_expense_model.dart';
import '../../../data/repositories/manufacturing_expense_repository.dart';
import 'manufacturing_expense_event.dart';
import 'manufacturing_expense_state.dart';

// Private internal events
class _ExpensesReceived extends ManufacturingExpenseEvent {
  final List<ManufacturingExpenseModel> expenses;
  const _ExpensesReceived(this.expenses);
  @override
  List<Object?> get props => [expenses];
}

class _ExpensesError extends ManufacturingExpenseEvent {
  final String message;
  const _ExpensesError(this.message);
  @override
  List<Object?> get props => [message];
}

class ManufacturingExpenseBloc
    extends Bloc<ManufacturingExpenseEvent, ManufacturingExpenseState> {
  final ManufacturingExpenseRepository _repository;
  StreamSubscription? _subscription;

  ManufacturingExpenseBloc({
    required ManufacturingExpenseRepository repository,
  })  : _repository = repository,
        super(ManufacturingExpenseInitial()) {
    on<ManufacturingExpenseLoadRequested>(_onLoad);
    on<_ExpensesReceived>(
        (event, emit) => emit(ManufacturingExpenseLoaded(expenses: event.expenses)));
    on<_ExpensesError>(
        (event, emit) => emit(ManufacturingExpenseError(message: event.message)));
    on<ManufacturingExpenseAddRequested>(_onAdd);
    on<ManufacturingExpenseUpdateRequested>(_onUpdate);
    on<ManufacturingExpenseDeleteRequested>(_onDelete);
  }

  Future<void> _onLoad(ManufacturingExpenseLoadRequested event,
      Emitter<ManufacturingExpenseState> emit) async {
    emit(ManufacturingExpenseLoading());
    await _subscription?.cancel();
    _subscription = _repository.getAll().listen(
      (expenses) { if (!isClosed) add(_ExpensesReceived(expenses)); },
      onError: (e) { if (!isClosed) add(_ExpensesError(e.toString())); },
    );
  }

  Future<void> _onAdd(ManufacturingExpenseAddRequested event,
      Emitter<ManufacturingExpenseState> emit) async {
    try {
      await _repository.add(event.expense);
      emit(const ManufacturingExpenseOperationSuccess(
          message: 'تم إضافة المصروف'));
    } catch (e) {
      emit(ManufacturingExpenseError(message: e.toString()));
    }
  }

  Future<void> _onUpdate(ManufacturingExpenseUpdateRequested event,
      Emitter<ManufacturingExpenseState> emit) async {
    try {
      await _repository.update(event.expense);
      emit(const ManufacturingExpenseOperationSuccess(
          message: 'تم تحديث المصروف'));
    } catch (e) {
      emit(ManufacturingExpenseError(message: e.toString()));
    }
  }

  Future<void> _onDelete(ManufacturingExpenseDeleteRequested event,
      Emitter<ManufacturingExpenseState> emit) async {
    try {
      await _repository.delete(event.id);
      emit(const ManufacturingExpenseOperationSuccess(
          message: 'تم حذف المصروف'));
    } catch (e) {
      emit(ManufacturingExpenseError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
