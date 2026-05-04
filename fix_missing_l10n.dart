import 'dart:io';

void main() async {
  final file = File('lib/features/dashboard/presentation/screens/dashboard_screen.dart');
  List<String> lines = await file.readAsLines();

  for (int i = 0; i < lines.length; i++) {
    // Add l10n final decl to missing methods (in this case _buildRecentOrders, _buildMonthlySalesChart, etc., which might be extracted)
    if (lines[i].contains('Widget _build') && lines[i].contains('BuildContext context')) {
      if (!lines[i + 1].contains('AppLocalizations.of(context)')) {
        lines.insert(i + 1, '    final l10n = AppLocalizations.of(context)!;');
      }
    }
  }
  
  await file.writeAsString(lines.join('\n'));
}