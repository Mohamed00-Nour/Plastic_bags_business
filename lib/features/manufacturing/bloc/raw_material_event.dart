import 'package:equatable/equatable.dart';
import '../../../data/models/raw_material_model.dart';

abstract class RawMaterialEvent extends Equatable {
  const RawMaterialEvent();
  @override
  List<Object?> get props => [];
}

class RawMaterialLoadRequested extends RawMaterialEvent {}

class RawMaterialSearchRequested extends RawMaterialEvent {
  final String query;
  const RawMaterialSearchRequested({required this.query});
  @override
  List<Object?> get props => [query];
}

class RawMaterialAddRequested extends RawMaterialEvent {
  final RawMaterialModel material;
  const RawMaterialAddRequested({required this.material});
  @override
  List<Object?> get props => [material];
}

class RawMaterialUpdateRequested extends RawMaterialEvent {
  final RawMaterialModel material;
  const RawMaterialUpdateRequested({required this.material});
  @override
  List<Object?> get props => [material];
}

class RawMaterialDeleteRequested extends RawMaterialEvent {
  final String id;
  const RawMaterialDeleteRequested({required this.id});
  @override
  List<Object?> get props => [id];
}
