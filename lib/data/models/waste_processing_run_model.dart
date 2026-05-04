import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'additional_cost.dart';

enum WasteResultType { rawMaterial, costOnly }

extension WasteResultTypeX on WasteResultType {
  String get label {
    switch (this) {
      case WasteResultType.rawMaterial:
        return 'خامة جديدة';
      case WasteResultType.costOnly:
        return 'تكلفة فقط';
    }
  }
}

class WasteProcessingRunModel extends Equatable {
  final String id;
  final String machineId;
  final String machineName;
  final double inputKg;
  final double outputKg;
  final double processingCost;
  final double transportCost;
  final List<AdditionalCost> additionalExpenses;
  final double totalCost;
  final double costPerKg;
  final WasteResultType resultType;
  final String? resultMaterialId;
  final String? resultMaterialName;
  final String? notes;
  final DateTime date;
  final String createdBy;
  final DateTime createdAt;

  const WasteProcessingRunModel({
    required this.id,
    required this.machineId,
    required this.machineName,
    required this.inputKg,
    required this.outputKg,
    this.processingCost = 0,
    this.transportCost = 0,
    this.additionalExpenses = const [],
    required this.totalCost,
    required this.costPerKg,
    required this.resultType,
    this.resultMaterialId,
    this.resultMaterialName,
    this.notes,
    required this.date,
    required this.createdBy,
    required this.createdAt,
  });

  double get lossKg => inputKg - outputKg;
  double get lossPercentage => inputKg > 0 ? (lossKg / inputKg) * 100 : 0;
  double get additionalExpensesTotal =>
      additionalExpenses.fold(0, (s, c) => s + c.amount);

  factory WasteProcessingRunModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawAdditional =
        data['additionalExpenses'] as List<dynamic>? ?? [];
    return WasteProcessingRunModel(
      id: doc.id,
      machineId: data['machineId'] ?? '',
      machineName: data['machineName'] ?? '',
      inputKg: (data['inputKg'] ?? 0).toDouble(),
      outputKg: (data['outputKg'] ?? 0).toDouble(),
      processingCost: (data['processingCost'] ?? 0).toDouble(),
      transportCost: (data['transportCost'] ?? 0).toDouble(),
      additionalExpenses: rawAdditional
          .map((c) => AdditionalCost.fromMap(c as Map<String, dynamic>))
          .toList(),
      totalCost: (data['totalCost'] ?? 0).toDouble(),
      costPerKg: (data['costPerKg'] ?? 0).toDouble(),
      resultType: WasteResultType.values.firstWhere(
        (t) => t.name == data['resultType'],
        orElse: () => WasteResultType.costOnly,
      ),
      resultMaterialId: data['resultMaterialId'],
      resultMaterialName: data['resultMaterialName'],
      notes: data['notes'],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'machineId': machineId,
        'machineName': machineName,
        'inputKg': inputKg,
        'outputKg': outputKg,
        'processingCost': processingCost,
        'transportCost': transportCost,
        'additionalExpenses':
            additionalExpenses.map((c) => c.toMap()).toList(),
        'totalCost': totalCost,
        'costPerKg': costPerKg,
        'resultType': resultType.name,
        'resultMaterialId': resultMaterialId,
        'resultMaterialName': resultMaterialName,
        'notes': notes,
        'date': Timestamp.fromDate(date),
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  WasteProcessingRunModel copyWith({
    String? id,
    String? machineId,
    String? machineName,
    double? inputKg,
    double? outputKg,
    double? processingCost,
    double? transportCost,
    List<AdditionalCost>? additionalExpenses,
    double? totalCost,
    double? costPerKg,
    WasteResultType? resultType,
    String? resultMaterialId,
    String? resultMaterialName,
    String? notes,
    DateTime? date,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return WasteProcessingRunModel(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      machineName: machineName ?? this.machineName,
      inputKg: inputKg ?? this.inputKg,
      outputKg: outputKg ?? this.outputKg,
      processingCost: processingCost ?? this.processingCost,
      transportCost: transportCost ?? this.transportCost,
      additionalExpenses: additionalExpenses ?? this.additionalExpenses,
      totalCost: totalCost ?? this.totalCost,
      costPerKg: costPerKg ?? this.costPerKg,
      resultType: resultType ?? this.resultType,
      resultMaterialId: resultMaterialId ?? this.resultMaterialId,
      resultMaterialName: resultMaterialName ?? this.resultMaterialName,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, machineId, inputKg, outputKg, totalCost, costPerKg, date];
}
