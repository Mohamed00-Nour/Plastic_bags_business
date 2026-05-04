import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/transaction_repository.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository _transactionRepository;
  StreamSubscription? _subscription;
  List<TransactionModel> _allTransactions = [];
  TransactionType? _currentFilter;

  TransactionBloc({required TransactionRepository transactionRepository})
      : _transactionRepository = transactionRepository,
        super(TransactionInitial()) {
    on<TransactionLoadRequested>(_onLoad);
    on<TransactionLoadByShop>(_onLoadByShop);
    on<TransactionLoadBySupplier>(_onLoadBySupplier);
    on<TransactionFilterByType>(_onFilterByType);
    on<TransactionSearchRequested>(_onSearch);
  }

  Future<void> _onLoad(
    TransactionLoadRequested event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());
    await _subscription?.cancel();
    _subscription = _transactionRepository.getTransactions().listen(
      (transactions) {
        _allTransactions = transactions;
        if (!isClosed) {
          add(const TransactionSearchRequested(query: ''));
        }
      },
      onError: (error) {
        if (!isClosed) {
          emit(TransactionError(message: error.toString()));
        }
      },
    );
  }

  Future<void> _onLoadByShop(
    TransactionLoadByShop event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());
    await _subscription?.cancel();
    _subscription =
        _transactionRepository.getTransactionsByShop(event.shopId).listen(
      (transactions) {
        _allTransactions = transactions;
        if (!isClosed) {
          add(const TransactionSearchRequested(query: ''));
        }
      },
      onError: (error) {
        if (!isClosed) {
          emit(TransactionError(message: error.toString()));
        }
      },
    );
  }

  Future<void> _onLoadBySupplier(
    TransactionLoadBySupplier event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());
    await _subscription?.cancel();
    _subscription = _transactionRepository
        .getTransactionsBySupplier(event.supplierId)
        .listen(
      (transactions) {
        _allTransactions = transactions;
        if (!isClosed) {
          add(const TransactionSearchRequested(query: ''));
        }
      },
      onError: (error) {
        if (!isClosed) {
          emit(TransactionError(message: error.toString()));
        }
      },
    );
  }

  void _onFilterByType(
    TransactionFilterByType event,
    Emitter<TransactionState> emit,
  ) {
    _currentFilter = event.type;
    add(const TransactionSearchRequested(query: ''));
  }

  void _onSearch(
    TransactionSearchRequested event,
    Emitter<TransactionState> emit,
  ) {
    var filtered = _allTransactions.toList();

    if (_currentFilter != null) {
      filtered = filtered.where((t) => t.type == _currentFilter).toList();
    }

    final query = event.query.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where((t) =>
              (t.shopName?.toLowerCase().contains(query) ?? false) ||
              (t.supplierName?.toLowerCase().contains(query) ?? false) ||
              (t.description?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    emit(TransactionLoaded(
      transactions: _allTransactions,
      filteredTransactions: filtered,
      filterType: _currentFilter,
    ));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
