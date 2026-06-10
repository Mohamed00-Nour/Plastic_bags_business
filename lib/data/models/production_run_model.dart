import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'additional_cost.dart';

class ProductionRunModel extends Equatable {
  final String id;
  final String mixId;
  final String mixName;
  final String productName;
  final double inputKg;
  final double outputKg;
  final double technicianCost;
  final double electricityCost;
  final List<AdditionalCost> additionalCosts;
  final double rawMaterialCost;
  final double totalCost;
  final double costPerKg;
  final String? notes;
  final DateTime date;
  final String createdBy;
  final String modifiedBy;
  final DateTime createdAt;

  const ProductionRunModel({
    required this.id,
    required this.mixId,
    required this.mixName,
    required this.productName,
    required this.inputKg,
    required this.outputKg,
    this.technicianCost = 0,
    this.electricityCost = 0,
    this.additionalCosts = const [],
    required this.rawMaterialCost,
    required this.totalCost,
    required this.costPerKg,
    this.notes,
    required this.date,
    required this.createdBy,
    this.modifiedBy = '',
    required this.createdAt,
  });

  double get wasteKg => inputKg - outputKg;
  double get wastePercentage =>
      inputKg > 0 ? (wasteKg / inputKg) * 100 : 0;
  double get additionalCostsTotal =>
      additionalCosts.fold(0, (s, c) => s + c.amount);

  factory ProductionRunModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawAdditional = data['additionalCosts'] as List<dynamic>? ?? [];
    return ProductionRunModel(
      id: doc.id,
      mixId: data['mixId'] ?? '',
      mixName: data['mixName'] ?? '',
      productName: data['productName'] ?? '',
      inputKg: (data['inputKg'] ?? 0).toDouble(),
      outputKg: (data['outputKg'] ?? 0).toDouble(),
      technicianCost: (data['technicianCost'] ?? 0).toDouble(),
      electricityCost: (data['electricityCost'] ?? 0).toDouble(),
      additionalCosts: rawAdditional
          .map((c) => AdditionalCost.fromMap(c as Map<String, dynamic>))
          .toList(),
      rawMaterialCost: (data['rawMaterialCost'] ?? 0).toDouble(),
      totalCost: (data['totalCost'] ?? 0).toDouble(),
      costPerKg: (data['costPerKg'] ?? 0).toDouble(),
      notes: data['notes'],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      modifiedBy: data['modifiedBy'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'mixId': mixId,
        'mixName': mixName,
        'productName': productName,
        'inputKg': inputKg,
        'outputKg': outputKg,
        'technicianCost': technicianCost,
        'electricityCost': electricityCost,
        'additionalCosts':
            additionalCosts.map((c) => c.toMap()).toList(),
        'rawMaterialCost': rawMaterialCost,
        'totalCost': totalCost,
        'costPerKg': costPerKg,
        'notes': notes,
        'date': Timestamp.fromDate(date),
        'createdBy': createdBy,
        'modifiedBy': modifiedBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  ProductionRunModel copyWith({
    String? id,
    String? mixId,
    String? mixName,
    String? productName,
    double? inputKg,
    double? outputKg,
    double? technicianCost,
    double? electricityCost,
    List<AdditionalCost>? additionalCosts,
    double? rawMaterialCost,
    double? totalCost,
    double? costPerKg,
    String? notes,
    DateTime? date,
    String? createdBy,
    String? modifiedBy,
    DateTime? createdAt,
  }) {
    return ProductionRunModel(
      id: id ?? this.id,
      mixId: mixId ?? this.mixId,
      mixName: mixName ?? this.mixName,
      productName: productName ?? this.productName,
      inputKg: inputKg ?? this.inputKg,
      outputKg: outputKg ?? this.outputKg,
      technicianCost: technicianCost ?? this.technicianCost,
      electricityCost: electricityCost ?? this.electricityCost,
      additionalCosts: additionalCosts ?? this.additionalCosts,
      rawMaterialCost: rawMaterialCost ?? this.rawMaterialCost,
      totalCost: totalCost ?? this.totalCost,
      costPerKg: costPerKg ?? this.costPerKg,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      modifiedBy: modifiedBy ?? this.modifiedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, mixId, inputKg, outputKg, totalCost, costPerKg, date];
}
