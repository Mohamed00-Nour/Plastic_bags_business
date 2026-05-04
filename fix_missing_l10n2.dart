import 'dart:io';

void main() async {
  final file = File('lib/features/dashboard/presentation/screens/dashboard_screen.dart');
  List<String> lines = await file.readAsLines();

  for (int i = 0; i < lines.length; i++) {
    // Add l10n declaration right after missing function signatures
    if (lines[i].contains('Widget _buildMonthlySalesChart(BuildContext context, DashboardLoaded state) {') && 
        !lines[i+1].contains('AppLocalizations.of(context)')) {
      lines.insert(i + 1, '    final l10n = AppLocalizations.of(context)!;');
    }
    if (lines[i].contains('Widget _buildTopProducts(BuildContext context, DashboardLoaded state) {') && 
        !lines[i+1].contains('AppLocalizations.of(context)')) {
      lines.insert(i + 1, '    final l10n = AppLocalizations.of(context)!;');
    }
    if (lines[i].contains('Widget _buildRecentOrders(BuildContext context, DashboardLoaded state) {') && 
        !lines[i+1].contains('AppLocalizations.of(context)')) {
      lines.insert(i + 1, '    final l10n = AppLocalizations.of(context)!;');
    }

    if (lines[i].contains('child: const Text(')) {
        lines[i] = lines[i].replaceAll('child: const Text(', 'child: Text(');
    }
    if (lines[i].contains('child: Text(l10n.noSalesData')) {
        // Look backwards to see if there is a const Center
        if (i > 0 && lines[i-1].contains('const Center(')) {
            lines[i-1] = lines[i-1].replaceAll('const Center(', 'Center(');
        }
    }
    if (lines[i].contains('DataColumn(label: const Text(')) {
        lines[i] = lines[i].replaceAll('DataColumn(label: const Text(', 'DataColumn(label: Text(');
    }
  }

  await file.writeAsString(lines.join('\n'));
}