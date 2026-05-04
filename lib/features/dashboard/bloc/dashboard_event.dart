import 'package:equatable/equatable.dart';

enum DashboardDateRange { today, week, month, year, all, custom }

extension DashboardDateRangeExtension on DashboardDateRange {
  String get label {
    switch (this) {
      case DashboardDateRange.today: return 'Today';
      case DashboardDateRange.week: return 'This Week';
      case DashboardDateRange.month: return 'This Month';
      case DashboardDateRange.year: return 'This Year';
      case DashboardDateRange.all: return 'All Time';
      case DashboardDateRange.custom: return 'Custom';
    }
  }
}

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object?> get props => [];
}

class DashboardLoadRequested extends DashboardEvent {}

class DashboardRefreshRequested extends DashboardEvent {}

class DashboardFilterChanged extends DashboardEvent {
  final DashboardDateRange range;
  const DashboardFilterChanged(this.range);
  @override
  List<Object?> get props => [range];
}

class DashboardCustomRangeChanged extends DashboardEvent {
  final DateTime start;
  final DateTime end;
  const DashboardCustomRangeChanged({required this.start, required this.end});
  @override
  List<Object?> get props => [start, end];
}
