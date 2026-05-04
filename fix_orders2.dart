import 'dart:io';

void main() {
  final file = File('lib/features/orders/presentation/screens/orders_screen.dart');
  var text = file.readAsStringSync();

  if (!text.contains("import 'package:flutter_gen/gen_l10n/app_localizations.dart';")) {
    text = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';\n" + text;
  }

  text = text.replaceAll('const DataColumn(', 'DataColumn(');
  text = text.replaceAll('const Center(\n                  child: Text(l10n', 'Center(\n                  child: Text(l10n');
  text = text.replaceAll('const Center(\n            child: Text(l10n', 'Center(\n            child: Text(l10n');
  
  // Fix the l10n undefined since we now added the import
  
  file.writeAsStringSync(text);
}