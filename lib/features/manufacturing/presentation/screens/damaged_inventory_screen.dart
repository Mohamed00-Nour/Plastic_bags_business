import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/damaged_inventory_model.dart';
import '../../../../data/repositories/damaged_inventory_repository.dart';

class DamagedInventoryScreen extends StatefulWidget {
  const DamagedInventoryScreen({super.key});

  @override
  State<DamagedInventoryScreen> createState() =>
      _DamagedInventoryScreenState();
}

class _DamagedInventoryScreenState extends State<DamagedInventoryScreen> {
  final DamagedInventoryRepository _repository = DamagedInventoryRepository();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.mfgDamagedInventoryTitle,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<DamagedInventoryModel>>(
              stream: _repository.getAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Text(l10n.mfgNoDamagedInventory),
                  );
                }

                final totalDamaged =
                    items.fold(0.0, (s, e) => s + e.signedKg);

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.warningColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.warningColor
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              color: AppTheme.warningColor),
                          const SizedBox(width: 12),
                          Text(
                            '${l10n.mfgTotalDamaged}: ${totalDamaged.toStringAsFixed(1)} ${l10n.mfgKg}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.warningColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final isDeduction = item.isDeduction;
                          return Card(
                            margin:
                                const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: (isDeduction
                                        ? AppTheme.dangerColor
                                        : AppTheme.warningColor)
                                    .withValues(alpha: 0.1),
                                child: Icon(
                                    isDeduction
                                        ? Icons.remove_circle_outline
                                        : Icons.broken_image_outlined,
                                    color: isDeduction
                                        ? AppTheme.dangerColor
                                        : AppTheme.warningColor),
                              ),
                              title: Text(
                                isDeduction
                                    ? item.productName
                                    : '${item.mixName} - ${item.productName}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${isDeduction ? '-' : ''}${item.damagedKg.toStringAsFixed(1)} ${l10n.mfgKg} | ${DateFormat('dd/MM/yyyy').format(item.date)}',
                              ),
                              trailing: Text(
                                item.createdBy,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
