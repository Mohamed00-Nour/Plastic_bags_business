import 'dart:io';

void main() async {
  final file = File('lib/features/dashboard/presentation/screens/dashboard_screen.dart');
  var text = await file.readAsString();

  // add context to missing build methods
  text = text.replaceAll('Widget _buildMonthlySalesChart(DashboardLoaded state) {', 'Widget _buildMonthlySalesChart(BuildContext context, DashboardLoaded state) {\n    final l10n = AppLocalizations.of(context)!;');
  text = text.replaceAll('_buildMonthlySalesChart(state)', '_buildMonthlySalesChart(context, state)');
  
  text = text.replaceAll('Widget _buildTopProducts(DashboardLoaded state) {', 'Widget _buildTopProducts(BuildContext context, DashboardLoaded state) {\n    final l10n = AppLocalizations.of(context)!;');
  text = text.replaceAll('_buildTopProducts(state)', '_buildTopProducts(context, state)');

  text = text.replaceAll('Widget _buildRecentOrders(DashboardLoaded state) {', 'Widget _buildRecentOrders(BuildContext context, DashboardLoaded state) {\n    final l10n = AppLocalizations.of(context)!;');
  text = text.replaceAll('_buildRecentOrders(state)', '_buildRecentOrders(context, state)');

  text = text.replaceAll('const Center(\n                      child: Text(l10n.noSalesData,', 'Center(\n                      child: Text(l10n.noSalesData,');
  text = text.replaceAll('const Padding(\n                padding: EdgeInsets.all(20),\n                child: Center(\n                  child: Text(l10n.noProductsYet,', 'Padding(\n                padding: const EdgeInsets.all(20),\n                child: Center(\n                  child: Text(l10n.noProductsYet,');
  text = text.replaceAll('const Padding(\n                padding: EdgeInsets.all(20),\n                child: Center(\n                  child: Text(l10n.noOrdersYet,', 'Padding(\n                padding: const EdgeInsets.all(20),\n                child: Center(\n                  child: Text(l10n.noOrdersYet,');

  text = text.replaceAll('const DataColumn(label: Text(l10n.', 'DataColumn(label: Text(l10n.');
  text = text.replaceAll('const [', '['); // safe brute force since we might have const lists with l10n inside DataColumns
  
  await file.writeAsString(text);
}
