import 'dart:io';

void main() async {
  final file = File('lib/features/dashboard/presentation/screens/dashboard_screen.dart');
  String text = await file.readAsString();

  text = text.replaceAll('final state = context.watch<DashboardBloc>().state;', 'final state = context.watch<DashboardBloc>().state;\n    final l10n = AppLocalizations.of(context)!;');

  final map = {
    "Text('Retry')": "Text(l10n.retry)",
    "Text('No sales data yet'": "Text(l10n.noSalesData",
    "Text('No products yet'": "Text(l10n.noProductsYet",
    "Text('No orders yet'": "Text(l10n.noOrdersYet",
    "label: Text('Order ID')": "label: Text(l10n.orderId)",
    "label: Text('Shop')": "label: Text(l10n.shop)",
    "label: Text('Total')": "label: Text(l10n.total)",
    "label: Text('Status')": "label: Text(l10n.status)",
    "label: Text('Date')": "label: Text(l10n.date)",
    "title: const Text('Recent Orders')": "title: Text(l10n.recentOrders)",
    "const Text('View All')": "Text(l10n.viewAll)",
    "title: 'Total Sales (Delivered)'": "title: l10n.totalSales",
    "title: 'Projected Sales (Pending)'": "title: l10n.projectedSales",
    "title: 'Total Profit'": "title: l10n.totalProfit",
    "title: 'Pending Orders'": "title: l10n.pendingOrders",
    "title: 'Active Shops'": "title: l10n.activeShops",
    "title: 'Low Stock Items'": "title: l10n.lowStockItems",
    "const Text('Monthly Sales'": "Text(l10n.monthlySales",
    "const Text('Top Products'": "Text(l10n.topProducts",
  };

  map.forEach((k, v) {
    text = text.replaceAll(k, v);
  });

  await file.writeAsString(text);
  print('Done!');
}
