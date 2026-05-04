import 'dart:io';

void main() {
  final file = File('lib/features/products/presentation/screens/products_screen_new.dart');
  var lines = file.readAsLinesSync();

  for (int i = 0; i < lines.length; i++) {
    var line = lines[i];

    if (line.contains("void _showProductForm(BuildContext context, {ProductModel? product}) {") ||
        line.contains("void _showStockDialog(BuildContext context, ProductModel product) {")) {
      if (!lines[i + 1].contains("final l10n = AppLocalizations.of(context)!;")) {
         lines.insert(i + 1, "    final l10n = AppLocalizations.of(context)!;");
      }
    }
  }

  file.writeAsStringSync(lines.join('\n'));
}