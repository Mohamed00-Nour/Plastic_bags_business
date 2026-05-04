import 'dart:io';

void main() {
  final file = File('lib/features/shops/presentation/screens/shops_screen.dart');
  var text = file.readAsStringSync();
  text = text.replaceAll(RegExp(r"\s*TextFormField\s*\(\s*controller:\s*creditCtrl,\s*decoration: const InputDecoration\s*\(\s*labelText:\s*'Credit Limit',\s*\),[\s\S]*?keyboardType:\s*TextInputType\.number,\s*\),\s*?", multiLine: true), "\n");
  file.writeAsStringSync(text);
}
