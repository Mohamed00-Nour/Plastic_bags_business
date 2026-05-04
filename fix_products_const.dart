import 'dart:io';

void main() {
  final file = File('lib/features/products/presentation/screens/products_screen_new.dart');
  var lines = file.readAsLinesSync();

  for (int i = 0; i < lines.length; i++) {
    var line = lines[i];

    if (line.contains("columns: const [")) {
      lines[i] = line.replaceAll("columns: const [", "columns: [");
    }
    
    if (line.contains("const Center(") && line.contains("l10n.")) {
      lines[i] = line.replaceAll("const Center(", "Center(");
    }
  }

  file.writeAsStringSync(lines.join('\n'));
}