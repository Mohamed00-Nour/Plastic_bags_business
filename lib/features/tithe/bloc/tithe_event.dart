import 'package:equatable/equatable.dart';
import '../../../data/models/tithe_payout_model.dart';

abstract class TitheEvent extends Equatable {
  const TitheEvent();

  @override
  List<Object?> get props => [];
}

class TitheLoadRequested extends TitheEvent {
  const TitheLoadRequested();
}

class TithePayoutsReceived extends TitheEvent {
  final List<TithePayoutModel> payouts;

  const TithePayoutsReceived({required this.payouts});

  @override
  List<Object?> get props => [payouts];
}

class TitheErrorOccurred extends TitheEvent {
  final String message;

  const TitheErrorOccurred({required this.message});

  @override
  List<Object?> get props => [message];
}

class TitheDateRangeChanged extends TitheEvent {
  final TitheDateRange range;
  final DateTime? customStart;
  final DateTime? customEnd;

  const TitheDateRangeChanged({
    required this.range,
    this.customStart,
    this.customEnd,
  });

  @override
  List<Object?> get props => [range, customStart, customEnd];
}

class TitheSearchChanged extends TitheEvent {
  final String query;

  const TitheSearchChanged({required this.query});

  @override
  List<Object?> get props => [query];
}

class TithePayoutCreated extends TitheEvent {
  final TithePayoutModel payout;

  const TithePayoutCreated({required this.payout});

  @override
  List<Object?> get props => [payout];
}

class TithePayoutUpdated extends TitheEvent {
  final TithePayoutModel payout;

  const TithePayoutUpdated({required this.payout});

  @override
  List<Object?> get props => [payout];
}

class TithePayoutDeleted extends TitheEvent {
  final String payoutId;

  const TithePayoutDeleted({required this.payoutId});

  @override
  List<Object?> get props => [payoutId];
}
