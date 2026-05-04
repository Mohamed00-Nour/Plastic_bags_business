import 'dart:io';
import 'dart:convert';

void main() {
  final file = File('lib/features/products/presentation/screens/products_screen_new.dart');
  var text = file.readAsStringSync();

  if (!text.contains("import 'package:flutter_gen/gen_l10n/app_localizations.dart';")) {
    text = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';\n" + text;
  }
  
  if (!text.contains("final l10n = AppLocalizations.of(context)!;")) {
    text = text.replaceAll('Widget build(BuildContext context) {', 'Widget build(BuildContext context) {\n    final l10n = AppLocalizations.of(context)!;');
  }

  final replacements = {
    "const Text('Add Product')": "Text(l10n.addProduct)",
    "label: Text('Name')": "label: Text(l10n.name)",
    "label: Text('Size')": "label: Text(l10n.size)",
    "label: Text('Cost')": "label: Text(l10n.cost)",
    "label: Text('Price')": "label: Text(l10n.price)",
    "label: Text('Stock')": "label: Text(l10n.stock)",
    "label: Text('Supplier')": "label: Text(l10n.supplier)",
    "label: Text('Actions')": "label: Text(l10n.actions)",
    "child: Text('No Supplier')": "child: Text(l10n.noSupplier)",
    "child: const Text('Cancel')": "child: Text(l10n.cancel)",
    "Text('Product: \${product.name}')": "Text('\${l10n.product}: \${product.name}')",
    "Text('Current Stock: \${product.stockQuantity}')": "Text('\${l10n.currentStock}: \${product.stockQuantity}')"
  };

  for (var entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  
  text = text.replaceAll("const Center(\n            child: Text(l10n.noOrdersFound", "Center(\n            child: Text(l10n.noOrdersFound");
  text = text.replaceAll("const DataColumn(", "DataColumn(");

  file.writeAsStringSync(text);

  final enFile = File('lib/l10n/app_en.arb');
  var dataEn = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;

  final newKeysEn = {
    'addProduct': 'Add Product',
    'name': 'Name',
    'size': 'Size',
    'cost': 'Cost',
    'price': 'Price',
    'stock': 'Stock',
    'supplier': 'Supplier',
    'noSupplier': 'No Supplier',
    'cancel': 'Cancel',
    'product': 'Product',
    'currentStock': 'Current Stock'
  };

  for (var entry in newKeysEn.entries) {
    dataEn.putIfAbsent(entry.key, () => entry.value);
  }

  enFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(dataEn));

  final arFile = File('lib/l10n/app_ar.arb');
  var dataAr = jsonDecode(arFile.readAsStringSync()) as Map<String, dynamic>;

  final newKeysAr = {
    'addProduct': 'إضافة منتج',
    'name': 'الاسم',
    'size': 'الحجم',
    'cost': 'التكلفة',
    'price': 'السعر',
    'stock': 'المخزون',
    'supplier': 'المورد',
    'noSupplier': 'لا يوجد مورد',
    'cancel': 'إلغاء',
    'product': 'المنتج',
    'currentStock': 'المخزون الحالي'
  };

  for (var entry in newKeysAr.entries) {
    dataAr.putIfAbsent(entry.key, () => entry.value);
  }

  arFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(dataAr));
}
