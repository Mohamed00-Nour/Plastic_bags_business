import 'dart:io';

void main() {
  final file = File('lib/features/products/presentation/screens/products_screen_new.dart');
  var lines = file.readAsLinesSync();

  for (int i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (line.contains("Widget _buildContent(ProductState state)") || 
        line.contains("Widget _buildContent(BuildContext context, ProductState state)") ||
        line.contains("void _showAddProductDialog(BuildContext context)") ||
        line.contains("void _showEditProductDialog(BuildContext context, Product product)") ||
        line.contains("void _showDeleteConfirmDialog(BuildContext context, Product product)")) {
      
      // inject if not already there
      if (!lines[i + 1].contains("final l10n = AppLocalizations.of(context)!;")) {
         lines.insert(i + 1, "    final l10n = AppLocalizations.of(context)!;");
      }
    }

    if (line.contains("Widget _buildContent(ProductState state)")) {
        lines[i] = line.replaceAll("Widget _buildContent(ProductState state)", "Widget _buildContent(BuildContext context, ProductState state)");
    }
    
    // fix the widget call
    if (line.contains("Expanded(child: _buildContent(state))")) {
        lines[i] = line.replaceAll("_buildContent(state)", "_buildContent(context, state)");
    }
    
    if (line.contains("const DataColumn(label: Text(l10n.")) {
        lines[i] = line.replaceAll("const DataColumn", "DataColumn");
    }
  }

  var text = lines.join('\n');
  
  // further cleanup of consts
  text = text.replaceAll('const DataColumn(', 'DataColumn(');
  text = text.replaceAll("child: const Text(l10n.cancel)", "child: Text(l10n.cancel)");
  text = text.replaceAll("title: const Text(l10n.addProduct)", "title: Text(l10n.addProduct)");
  
  // run flutter_gen again
  
  file.writeAsStringSync(text);
}
