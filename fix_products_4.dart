import 'dart:io';

void main() {
  final file = File('lib/features/products/presentation/screens/products_screen_new.dart');
  var text = file.readAsStringSync();
  
  if (text.indexOf("_showStockDialog") > -1 && !text.contains("final l10n = AppLocalizations.of(context)!;", text.indexOf("_showStockDialog"))) {
     text = text.replaceFirst("void _showStockDialog(\n    BuildContext context,\n    ProductModel product,\n    bool isIncrease,\n  ) {",
     "void _showStockDialog(\n    BuildContext context,\n    ProductModel product,\n    bool isIncrease,\n  ) {\n    final l10n = AppLocalizations.of(context)!;");
  }
  
  if (text.indexOf("_showProductForm") > -1 && !text.contains("final l10n = AppLocalizations.of(context)!;", text.indexOf("_showProductForm"))) {
     text = text.replaceFirst("void _showProductForm(BuildContext context, {ProductModel? product}) {",
     "void _showProductForm(BuildContext context, {ProductModel? product}) {\n    final l10n = AppLocalizations.of(context)!;");
  }

  text = text.replaceAll(RegExp(r'const\s+Text\(l10n'), 'Text(l10n');
  text = text.replaceAll(RegExp(r'const\s+Center\(\s*child:\s*Text\(l10n'), 'Center(child: Text(l10n');

  file.writeAsStringSync(text);
}
