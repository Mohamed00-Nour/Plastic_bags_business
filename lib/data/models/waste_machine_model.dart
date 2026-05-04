import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class WasteMachineModel extends Equatable {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  const WasteMachineModel({
    required this.id,
    required this.name,
    this.isActive = true,
    required this.createdAt,
  });

  factory WasteMachineModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WasteMachineModel(
      id: doc.id,
      name: data['name'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  WasteMachineModel copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return WasteMachineModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, isActive];
}
