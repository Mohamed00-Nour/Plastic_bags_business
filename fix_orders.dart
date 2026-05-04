import 'dart:io';
import 'dart:convert';

void main() {
  final file = File('lib/features/orders/presentation/screens/orders_screen.dart');
  var text = file.readAsStringSync();

  text = text.replaceAll('Widget build(BuildContext context) {', 'Widget build(BuildContext context) {\n    final l10n = AppLocalizations.of(context)!;');

  final replacements = {
    "const Text('Orders')": "Text(l10n.orders)",
    "const Text('Orders',": "Text(l10n.orders,",
    "Text('Retry')": "Text(l10n.retry)",
    "Text('No orders found')": "Text(l10n.noOrdersFound)",
    "label: const Text('Order ID')": "label: Text(l10n.orderId)",
    "label: const Text('Shop')": "label: Text(l10n.shop)",
    "label: const Text('Total')": "label: Text(l10n.total)",
    "label: const Text('Status')": "label: Text(l10n.status)",
    "label: const Text('Date')": "label: Text(l10n.date)",
    "label: const Text('Actions')": "label: Text(l10n.actions)",

    "label: Text('Order ID')": "label: Text(l10n.orderId)",
    "label: Text('Shop')": "label: Text(l10n.shop)",
    "label: Text('Total')": "label: Text(l10n.total)",
    "label: Text('Status')": "label: Text(l10n.status)",
    "label: Text('Date')": "label: Text(l10n.date)",
    "label: Text('Actions')": "label: Text(l10n.actions)",
    "const Text('Delivery Address')": "Text(l10n.deliveryAddress)",
    "const Text('Customer Name')": "Text(l10n.customerName)",
    "const Text('Phone Number')": "Text(l10n.phoneNumber)",
    "const Text('Items')": "Text(l10n.items)",

    "hintText: 'Search orders...',": "hintText: l10n.searchOrders,",
    "const Center(\n                  child: Text(l10n.noOrdersFound": "Center(\n                  child: Text(l10n.noOrdersFound",
    "const Center(\n            child: Text(l10n.noOrdersFound": "Center(\n            child: Text(l10n.noOrdersFound"
  };

  for (var entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }

  file.writeAsStringSync(text);

  final enFile = File('lib/l10n/app_en.arb');
  var dataEn = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;

  final newKeysEn = {
    'orders': 'Orders',
    'noOrdersFound': 'No orders found',
    'actions': 'Actions',
    'deliveryAddress': 'Delivery Address',
    'customerName': 'Customer Name',
    'phoneNumber': 'Phone Number',
    'items': 'Items',
    'searchOrders': 'Search orders...'
  };

  for (var entry in newKeysEn.entries) {
    dataEn.putIfAbsent(entry.key, () => entry.value);
  }

  enFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(dataEn));

  final arFile = File('lib/l10n/app_ar.arb');
  var dataAr = jsonDecode(arFile.readAsStringSync()) as Map<String, dynamic>;

  final newKeysAr = {
    'orders': 'الطلبات',
    'noOrdersFound': 'لم يتم العثور على طلبات',
    'actions': 'الإجراءات',
    'deliveryAddress': 'عنوان التوصيل',
    'customerName': 'اسم الزبون',
    'phoneNumber': 'رقم الهاتف',
    'items': 'العناصر',
    'searchOrders': 'ابحث في الطلبات...'
  };

  for (var entry in newKeysAr.entries) {
    dataAr.putIfAbsent(entry.key, () => entry.value);
  }

  arFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(dataAr));
}
