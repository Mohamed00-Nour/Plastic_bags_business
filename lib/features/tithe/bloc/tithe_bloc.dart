import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/tithe_payout_model.dart';
import '../../../data/repositories/tithe_repository.dart';
import 'tithe_event.dart';
import 'tithe_state.dart';

class TitheBloc extends Bloc<TitheEvent, TitheState> {
  final TitheRepository _titheRepository;
  StreamSubscription<List<TithePayoutModel>>? _payoutsSubscription;

  List<TithePayoutModel> _allPayouts = [];
  TitheFinancialData _financialData = TitheFinancialData.empty();
  TitheDateRange _currentRange = TitheDateRange.all;
  String _currentQuery = '';
  DateTime? _customStart;
  DateTime? _customEnd;

  TitheBloc({required TitheRepository titheRepository})
      : _titheRepository = titheRepository,
        super(TitheInitial()) {
    on<TitheLoadRequested>(_onLoad);
    on<TithePayoutsReceived>(_onPayoutsReceived);
    on<TitheErrorOccurred>(_onErrorOccurred);
    on<TitheDateRangeChanged>(_onDateRangeChanged);
    on<TitheSearchChanged>(_onSearchChanged);
    on<TithePayoutCreated>(_onPayoutCreated);
    on<TithePayoutUpdated>(_onPayoutUpdated);
    on<TithePayoutDeleted>(_onPayoutDeleted);
  }

  Future<void> _onLoad(
    TitheLoadRequested event,
    Emitter<TitheState> emit,
  ) async {
    emit(TitheLoading());
    await _payoutsSubscription?.cancel();

    try {
      _financialData = await _titheRepository.calculateTitheFinancials();
    } catch (_) {
      _financialData = TitheFinancialData.empty();
    }

    _payoutsSubscription = _titheRepository.getPayoutsStream().listen(
      (payouts) {
        if (!isClosed) {
          add(TithePayoutsReceived(payouts: payouts));
        }
      },
      onError: (error) {
        if (!isClosed) {
          add(TitheErrorOccurred(message: error.toString()));
        }
      },
    );
  }

  void _onPayoutsReceived(
    TithePayoutsReceived event,
    Emitter<TitheState> emit,
  ) {
    _allPayouts = event.payouts;
    _emitCurrentState(emit);
  }

  void _onErrorOccurred(
    TitheErrorOccurred event,
    Emitter<TitheState> emit,
  ) {
    emit(TitheError(message: event.message));
  }

  void _onDateRangeChanged(
    TitheDateRangeChanged event,
    Emitter<TitheState> emit,
  ) {
    _currentRange = event.range;
    _customStart = event.customStart;
    _customEnd = event.customEnd;
    _emitCurrentState(emit);
  }

  void _onSearchChanged(
    TitheSearchChanged event,
    Emitter<TitheState> emit,
  ) {
    _currentQuery = event.query;
    _emitCurrentState(emit);
  }

  Future<void> _onPayoutCreated(
    TithePayoutCreated event,
    Emitter<TitheState> emit,
  ) async {
    try {
      await _titheRepository.addPayout(event.payout);
    } catch (e) {
      emit(TitheError(message: e.toString()));
    }
  }

  Future<void> _onPayoutUpdated(
    TithePayoutUpdated event,
    Emitter<TitheState> emit,
  ) async {
    try {
      await _titheRepository.updatePayout(event.payout);
    } catch (e) {
      emit(TitheError(message: e.toString()));
    }
  }

  Future<void> _onPayoutDeleted(
    TithePayoutDeleted event,
    Emitter<TitheState> emit,
  ) async {
    try {
      await _titheRepository.deletePayout(event.payoutId);
    } catch (e) {
      emit(TitheError(message: e.toString()));
    }
  }

  void _emitCurrentState(Emitter<TitheState> emit) {
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // 1. Calculate Monthly Payouts
    final monthlyPayoutMap = <String, double>{};
    double totalDisbursed = 0.0;
    double currentMonthDisbursed = 0.0;

    for (final payout in _allPayouts) {
      totalDisbursed += payout.amount;
      final key = '${payout.date.year}-${payout.date.month.toString().padLeft(2, '0')}';
      monthlyPayoutMap[key] = (monthlyPayoutMap[key] ?? 0.0) + payout.amount;
      if (key == currentMonthKey) {
        currentMonthDisbursed += payout.amount;
      }
    }

    // 2. Build distinct month keys
    final allMonthKeys = <String>{
      ..._financialData.monthlyProfit.keys,
      ...monthlyPayoutMap.keys,
      currentMonthKey,
    }.toList()
      ..sort((a, b) => b.compareTo(a)); // Descending chronological order

    final monthlySummaries = <MonthlyTitheSummary>[];
    for (final key in allMonthKeys) {
      final parts = key.split('-');
      final year = int.tryParse(parts[0]) ?? now.year;
      final month = int.tryParse(parts[1]) ?? now.month;
      final monthDate = DateTime(year, month, 1);

      final salesRev = _financialData.monthlySalesRevenue[key] ?? 0.0;
      final netProf = _financialData.monthlyProfit[key] ?? 0.0;
      final titheAccrued = _financialData.monthlyTithe[key] ?? (netProf > 0 ? netProf * 0.10 : 0.0);
      final disbursed = monthlyPayoutMap[key] ?? 0.0;

      monthlySummaries.add(MonthlyTitheSummary(
        monthKey: key,
        monthDate: monthDate,
        salesRevenue: salesRev,
        netProfit: netProf,
        titheAccrued: titheAccrued,
        titheDisbursed: disbursed,
        netRemaining: titheAccrued - disbursed,
      ));
    }

    // Current month stats
    final currentMonthProfit = _financialData.monthlyProfit[currentMonthKey] ?? 0.0;
    final currentMonthTithe = _financialData.monthlyTithe[currentMonthKey] ??
        (currentMonthProfit > 0 ? currentMonthProfit * 0.10 : 0.0);
    final currentMonthNetRemaining = currentMonthTithe - currentMonthDisbursed;

    // Total tithe balance
    final currentBalance = _financialData.totalAllTimeTithe - totalDisbursed;

    // 3. Filter payouts
    final filterStart = _getFilterStartDate();
    final filterEnd = _getFilterEndDate();

    var filtered = _allPayouts.where((p) {
      if (filterStart != null && p.date.isBefore(filterStart)) return false;
      if (filterEnd != null && p.date.isAfter(filterEnd)) return false;
      return true;
    }).toList();

    final query = _currentQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((p) {
        return p.recipient.toLowerCase().contains(query) ||
            p.notes.toLowerCase().contains(query) ||
            p.createdByName.toLowerCase().contains(query);
      }).toList();
    }

    double filteredTotal = 0.0;
    for (final p in filtered) {
      filteredTotal += p.amount;
    }

    emit(TitheLoaded(
      totalAllTimeProfit: _financialData.totalAllTimeProfit,
      totalAllTimeTithe: _financialData.totalAllTimeTithe,
      totalAllTimeDisbursed: totalDisbursed,
      currentBalance: currentBalance,
      currentMonthProfit: currentMonthProfit,
      currentMonthTithe: currentMonthTithe,
      currentMonthDisbursed: currentMonthDisbursed,
      currentMonthNetRemaining: currentMonthNetRemaining,
      monthlyBreakdown: monthlySummaries,
      allPayouts: _allPayouts,
      filteredPayouts: filtered,
      filteredPayoutsTotal: filteredTotal,
      selectedRange: _currentRange,
      searchQuery: _currentQuery,
      customStart: _customStart,
      customEnd: _customEnd,
    ));
  }

  DateTime? _getFilterStartDate() {
    final now = DateTime.now();
    switch (_currentRange) {
      case TitheDateRange.all:
        return null;
      case TitheDateRange.today:
        return DateTime(now.year, now.month, now.day);
      case TitheDateRange.thisWeek:
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday % 7));
      case TitheDateRange.thisMonth:
        return DateTime(now.year, now.month, 1);
      case TitheDateRange.lastMonth:
        return DateTime(now.year, now.month - 1, 1);
      case TitheDateRange.thisYear:
        return DateTime(now.year, 1, 1);
      case TitheDateRange.custom:
        return _customStart;
    }
  }

  DateTime? _getFilterEndDate() {
    final now = DateTime.now();
    switch (_currentRange) {
      case TitheDateRange.all:
        return null;
      case TitheDateRange.today:
        return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      case TitheDateRange.thisWeek:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday % 7));
        return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      case TitheDateRange.thisMonth:
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        return nextMonth.subtract(const Duration(microseconds: 1));
      case TitheDateRange.lastMonth:
        final thisMonth = DateTime(now.year, now.month, 1);
        return thisMonth.subtract(const Duration(microseconds: 1));
      case TitheDateRange.thisYear:
        final nextYear = DateTime(now.year + 1, 1, 1);
        return nextYear.subtract(const Duration(microseconds: 1));
      case TitheDateRange.custom:
        if (_customEnd != null) {
          return DateTime(
            _customEnd!.year,
            _customEnd!.month,
            _customEnd!.day,
            23,
            59,
            59,
            999,
          );
        }
        return null;
    }
  }

  @override
  Future<void> close() {
    _payoutsSubscription?.cancel();
    return super.close();
  }
}
