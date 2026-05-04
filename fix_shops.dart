import 'dart:io';

void main() {
  final file = File('lib/features/shops/presentation/screens/shops_screen.dart');
  var text = file.readAsStringSync();

  text = text.replaceAll(RegExp(r"DataColumn\s*\(\s*label:\s*Text\s*\(\s*'Balance'\s*\)\s*,\s*numeric:\s*true\s*\)\s*,\s*?", multiLine: true), "");
  text = text.replaceAll(RegExp(r"DataColumn\s*\(\s*label:\s*Text\s*\(\s*'Credit Limit'\s*\)\s*,\s*numeric:\s*true\s*\)\s*,\s*?", multiLine: true), "");

  text = text.replaceAll(RegExp(r"DataCell\s*\(\s*Text\s*\(\s*currFmt\.format\(shop\.balance\),\s*style: TextStyle\(\s*color: shop\.balance >= 0[\s\S]*?fontWeight: FontWeight\.w500,\s*\),\s*\)\s*\),\s*?", multiLine: true), "");
  text = text.replaceAll(RegExp(r"DataCell\s*\(\s*Text\s*\(\s*currFmt\.format\(\s*shop\.creditLimit\s*\)\s*\)\s*\)\s*,\s*?", multiLine: true), "");

  text = text.replaceAll(RegExp(r"IconButton\s*\(\s*icon:\s*const\s*Icon\s*\(\s*Icons\.account_balance_wallet[\s\S]*?tooltip:\s*'Charge Balance'[\s\S]*?_showChargeDialog\s*\(\s*context\s*,\s*shop\s*\)\s*,\s*\)\s*,\s*?", multiLine: true), "");

  text = text.replaceAll(RegExp(r"\s*final\s+creditCtrl\s*=\s*TextEditingController\s*\(\s*text:\s*shop\?\.creditLimit\.toString\(\)\s*\?\?\s*'0'\s*\)\s*;\s*?", multiLine: true), "\n");
  text = text.replaceAll(RegExp(r"\s*TextField\s*\(\s*controller:\s*creditCtrl,\s*decoration: const InputDecoration\s*\(\s*labelText:\s*'Credit Limit'\s*\),[\s\S]*?keyboardType:\s*TextInputType\.number,\s*\),\s*?", multiLine: true), "\n");

  text = text.replaceAll(RegExp(r"\s*balance:\s*shop\?\.balance\s*\?\?\s*0\s*,\s*?", multiLine: true), "\n");
  text = text.replaceAll(RegExp(r"\s*creditLimit:\s*double\.tryParse\(\s*creditCtrl\.text\s*\)\s*\?\?\s*0\s*,\s*?", multiLine: true), "\n");

  text = text.replaceAll(RegExp(r"void\s*_showChargeDialog[\s\S]*?\}\s*void\s*_showShopTransactions"), "void _showShopTransactions");

  text = text.replaceAll(RegExp(r"DataColumn\s*\(\s*label:\s*Text\s*\(\s*'Balance'\s*\)\s*,\s*numeric:\s*true\s*\)\s*,\s*?", multiLine: true), "");
  text = text.replaceAll(RegExp(r"final\s+isCredit[\s\S]*?t\.type\s*==\s*TransactionType\.refund\s*;\s*?", multiLine: true), "final isCredit = t.type == TransactionType.refund;\n                        ");
  text = text.replaceAll(RegExp(r"DataCell\s*\(\s*Text\s*\(\s*currFmt\.format\(\s*t\.balanceAfter\s*\)\s*\)\s*\)\s*,\s*?", multiLine: true), "");

  file.writeAsStringSync(text);
}
