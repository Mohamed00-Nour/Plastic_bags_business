import 'dart:io';

void main() {
  final file = File('lib/features/products/presentation/screens/products_screen_new.dart');
  var text = file.readAsStringSync();
  
  text = text.replaceAll('const DropdownMenuItem<String>(\n                                      value: null,\n                                      child: Text(l10n.noSupplier),\n                                    ),', 
                         'DropdownMenuItem<String>(\n                                      value: null,\n                                      child: Text(l10n.noSupplier),\n                                    ),');

  // Insert l10n inside the dialog builder 
  text = text.replaceAll('builder:\n                (context, setState) => AlertDialog(',
                         'builder:\n                (context, setState) {\n                  final l10n = AppLocalizations.of(context)!;\n                  return AlertDialog(');
                         
  text = text.replaceAll('title: Text(isIncrease ? \'Increase Stock\' : \'Decrease Stock\'),',
                         'title: Text(isIncrease ? \'Increase Stock\' : \'Decrease Stock\'),').replaceAll('           content: SizedBox(', '           content: SizedBox(').replaceAll('                 actions: [\n                    TextButton(', '                 actions: [\n                    TextButton(');

  text = text.replaceAll('              )\n            ),', '              );\n            },');
  text = text.replaceAll('builder:\n          (ctx) => StatefulBuilder(', 'builder:\n          (ctx) {\n            final l10n = AppLocalizations.of(ctx)!;\n            return StatefulBuilder(');
  text = text.replaceAll('        ),\n      );', '        );\n      },');

  file.writeAsStringSync(text);
}
