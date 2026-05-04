import 'package:equatable/equatable.dart';

abstract class ReportEvent extends Equatable {
  const ReportEvent();
  @override
  List<Object?> get props => [];
}

class ReportLoadRequested extends ReportEvent {
  final DateTime startDate;
  final DateTime endDate;
  const ReportLoadRequested({required this.startDate, required this.endDate});
  @override
  List<Object?> get props => [startDate, endDate];
}

class ReportGeneratePdf extends ReportEvent {
  final String reportType;
  final DateTime startDate;
  final DateTime endDate;
  final String? entityId;
  const ReportGeneratePdf({
    required this.reportType,
    required this.startDate,
    required this.endDate,
    this.entityId,
  });
  @override
  List<Object?> get props => [reportType, startDate, endDate, entityId];
}
