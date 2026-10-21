import 'package:equatable/equatable.dart';
import '../../../data/models/tithe_payout_model.dart';

abstract class TitheState extends Equatable {
  const TitheState();

  @override
  List<Object?> get props => [];
}

class TitheInitial extends TitheState {}

class TitheLoading extends TitheState {}

class TitheLoaded extends TitheState {
  final double totalAllTimeProfit;
  final double totalAllTimeTithe;
  final double totalAllTimeDisbursed;
  final double currentBalance; // totalAllTimeTithe - totalAllTimeDisbursed

  final double currentMonthProfit;
  final double currentMonthTithe;
  final double currentMonthDisbursed;
  final double currentMonthNetRemaining;

  final List<MonthlyTitheSummary> monthlyBreakdown;
  final List<TithePayoutModel> allPayouts;
  final List<TithePayoutModel> filteredPayouts;

  final double filteredPayoutsTotal;

  final TitheDateRange selectedRange;
  final String searchQuery;
  final DateTime? customStart;
  final DateTime? customEnd;

  const TitheLoaded({
    required this.totalAllTimeProfit,
    required this.totalAllTimeTithe,
    required this.totalAllTimeDisbursed,
    required this.currentBalance,
    required this.currentMonthProfit,
    required this.currentMonthTithe,
    required this.currentMonthDisbursed,
    required this.currentMonthNetRemaining,
    required this.monthlyBreakdown,
    required this.allPayouts,
    required this.filteredPayouts,
    required this.filteredPayoutsTotal,
    this.selectedRange = TitheDateRange.all,
    this.searchQuery = '',
    this.customStart,
    this.customEnd,
  });

  TitheLoaded copyWith({
    double? totalAllTimeProfit,
    double? totalAllTimeTithe,
    double? totalAllTimeDisbursed,
    double? currentBalance,
    double? currentMonthProfit,
    double? currentMonthTithe,
    double? currentMonthDisbursed,
    double? currentMonthNetRemaining,
    List<MonthlyTitheSummary>? monthlyBreakdown,
    List<TithePayoutModel>? allPayouts,
    List<TithePayoutModel>? filteredPayouts,
    double? filteredPayoutsTotal,
    TitheDateRange? selectedRange,
    String? searchQuery,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    return TitheLoaded(
      totalAllTimeProfit: totalAllTimeProfit ?? this.totalAllTimeProfit,
      totalAllTimeTithe: totalAllTimeTithe ?? this.totalAllTimeTithe,
      totalAllTimeDisbursed: totalAllTimeDisbursed ?? this.totalAllTimeDisbursed,
      currentBalance: currentBalance ?? this.currentBalance,
      currentMonthProfit: currentMonthProfit ?? this.currentMonthProfit,
      currentMonthTithe: currentMonthTithe ?? this.currentMonthTithe,
      currentMonthDisbursed: currentMonthDisbursed ?? this.currentMonthDisbursed,
      currentMonthNetRemaining: currentMonthNetRemaining ?? this.currentMonthNetRemaining,
      monthlyBreakdown: monthlyBreakdown ?? this.monthlyBreakdown,
      allPayouts: allPayouts ?? this.allPayouts,
      filteredPayouts: filteredPayouts ?? this.filteredPayouts,
      filteredPayoutsTotal: filteredPayoutsTotal ?? this.filteredPayoutsTotal,
      selectedRange: selectedRange ?? this.selectedRange,
      searchQuery: searchQuery ?? this.searchQuery,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
    );
  }

  @override
  List<Object?> get props => [
        totalAllTimeProfit,
        totalAllTimeTithe,
        totalAllTimeDisbursed,
        currentBalance,
        currentMonthProfit,
        currentMonthTithe,
        currentMonthDisbursed,
        currentMonthNetRemaining,
        monthlyBreakdown,
        allPayouts,
        filteredPayouts,
        filteredPayoutsTotal,
        selectedRange,
        searchQuery,
        customStart,
        customEnd,
      ];
}

class TitheError extends TitheState {
  final String message;

  const TitheError({required this.message});

  @override
  List<Object?> get props => [message];
}
