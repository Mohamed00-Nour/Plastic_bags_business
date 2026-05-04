import sys

with open('lib/features/dashboard/presentation/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('final state = context.watch<DashboardBloc>().state;', 'final state = context.watch<DashboardBloc>().state;\n    final l10n = AppLocalizations.of(context)!;')

replacements = {
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
}

for k, v in replacements.items():
    text = text.replace(k, v)

with open('lib/features/dashboard/presentation/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
