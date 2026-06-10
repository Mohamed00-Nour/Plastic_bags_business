import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'additional_cost.dart';
import 'custom_run_field.dart';

enum ProductionRunStatus { draft, executed }

class ProductionRunModel extends Equatable {
  final String id;
  final String mixId;
  final String mixName;
  final String productName;
  final double inputKg;
  final double? outputKg;
  final double? damagedKg;
  final double technicianCost;
  final double electricityCost;
  final List<AdditionalCost> additionalCosts;
  final List<CustomRunField> customFields;
  final double rawMaterialCost;
  final double totalCost;
  final double costPerKg;
  final ProductionRunStatus status;
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
    this.outputKg,
    this.damagedKg,
    this.technicianCost = 0,
    this.electricityCost = 0,
    this.additionalCosts = const [],
    this.customFields = const [],
    this.rawMaterialCost = 0,
    this.totalCost = 0,
    this.costPerKg = 0,
    this.status = ProductionRunStatus.draft,
    this.notes,
    required this.date,
    required this.createdBy,
    this.modifiedBy = '',
    required this.createdAt,
  });

  double get effectiveOutputKg => outputKg ?? 0;
  double get effectiveDamagedKg => damagedKg ?? 0;

  double get customCostTotal =>
      customFields.fold(0.0, (s, f) => s + f.value);

  /// damagedKg is auto-calculated: input - output
  double get calculatedDamagedKg => inputKg - effectiveOutputKg;

  bool get isExecuted => status == ProductionRunStatus.executed;

  bool get canExecute =>
      outputKg != null &&
      effectiveOutputKg > 0 &&
      !isExecuted;

  double get wasteKg => inputKg - effectiveOutputKg;
  double get wastePercentage =>
      inputKg > 0 ? (wasteKg / inputKg) * 100 : 0;
  double get additionalCostsTotal =>
      additionalCosts.fold(0, (s, c) => s + c.amount);

  factory ProductionRunModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawAdditional = data['additionalCosts'] as List<dynamic>? ?? [];
    final rawCustom = data['customFields'] as List<dynamic>? ?? [];
    return ProductionRunModel(
      id: doc.id,
      mixId: data['mixId'] ?? '',
      mixName: data['mixName'] ?? '',
      productName: data['productName'] ?? '',
      inputKg: (data['inputKg'] ?? 0).toDouble(),
      outputKg: data['outputKg'] != null
          ? (data['outputKg'] as num).toDouble()
          : null,
      damagedKg: data['damagedKg'] != null
          ? (data['damagedKg'] as num).toDouble()
          : null,
      technicianCost: (data['technicianCost'] ?? 0).toDouble(),
      electricityCost: (data['electricityCost'] ?? 0).toDouble(),
      additionalCosts: rawAdditional
          .map((c) => AdditionalCost.fromMap(c as Map<String, dynamic>))
          .toList(),
      customFields: rawCustom
          .map((c) => CustomRunField.fromMap(c as Map<String, dynamic>))
          .toList(),
      rawMaterialCost: (data['rawMaterialCost'] ?? 0).toDouble(),
      totalCost: (data['totalCost'] ?? 0).toDouble(),
      costPerKg: (data['costPerKg'] ?? 0).toDouble(),
      status: data['status'] == 'executed'
          ? ProductionRunStatus.executed
          : ProductionRunStatus.draft,
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
        'damagedKg': damagedKg,
        'technicianCost': technicianCost,
        'electricityCost': electricityCost,
        'additionalCosts':
            additionalCosts.map((c) => c.toMap()).toList(),
        'customFields':
            customFields.map((c) => c.toMap()).toList(),
        'rawMaterialCost': rawMaterialCost,
        'totalCost': totalCost,
        'costPerKg': costPerKg,
        'status': status == ProductionRunStatus.executed
            ? 'executed'
            : 'draft',
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
    double? damagedKg,
    double? technicianCost,
    double? electricityCost,
    List<AdditionalCost>? additionalCosts,
    List<CustomRunField>? customFields,
    double? rawMaterialCost,
    double? totalCost,
    double? costPerKg,
    ProductionRunStatus? status,
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
      damagedKg: damagedKg ?? this.damagedKg,
      technicianCost: technicianCost ?? this.technicianCost,
      electricityCost: electricityCost ?? this.electricityCost,
      additionalCosts: additionalCosts ?? this.additionalCosts,
      customFields: customFields ?? this.customFields,
      rawMaterialCost: rawMaterialCost ?? this.rawMaterialCost,
      totalCost: totalCost ?? this.totalCost,
      costPerKg: costPerKg ?? this.costPerKg,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      modifiedBy: modifiedBy ?? this.modifiedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, mixId, inputKg, outputKg, totalCost, costPerKg, date, status];
}
