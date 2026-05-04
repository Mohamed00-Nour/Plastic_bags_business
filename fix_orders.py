import os

with open('lib/features/orders/presentation/screens/orders_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('Widget build(BuildContext context) {', 'Widget build(BuildContext context) {\n    final l10n = AppLocalizations.of(context)!;')

replacements = {
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
    "const Center(\n                  child: Text(l10n.noOrdersFound": "Center(\n                  child: Text(l10n.noOrdersFound"
}

for k, v in replacements.items():
    text = text.replace(k, v)

with open('lib/features/orders/presentation/screens/orders_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

import json
with open('lib/l10n/app_en.arb', 'r', encoding='utf-8') as f:
    data = json.loads(f.read())

new_keys = {
    'orders': 'Orders',
    'noOrdersFound': 'No orders found',
    'actions': 'Actions',
    'deliveryAddress': 'Delivery Address',
    'customerName': 'Customer Name',
    'phoneNumber': 'Phone Number',
    'items': 'Items',
    'searchOrders': 'Search orders...'
}

for k, v in new_keys.items():
    if k not in data:
        data[k] = v

with open('lib/l10n/app_en.arb', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)


with open('lib/l10n/app_ar.arb', 'r', encoding='utf-8') as f:
    data_ar = json.loads(f.read())

new_keys_ar = {
    'orders': 'الطلبات',
    'noOrdersFound': 'لم يتم العثور على طلبات',
    'actions': 'الإجراءات',
    'deliveryAddress': 'عنوان التوصيل',
    'customerName': 'اسم الزبون',
    'phoneNumber': 'رقم الهاتف',
    'items': 'العناصر',
    'searchOrders': 'ابحث في الطلبات...'
}

for k, v in new_keys_ar.items():
    if k not in data_ar:
        data_ar[k] = v

with open('lib/l10n/app_ar.arb', 'w', encoding='utf-8') as f:
    json.dump(data_ar, f, indent=2, ensure_ascii=False)
