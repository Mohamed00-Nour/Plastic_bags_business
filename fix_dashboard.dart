import 'dart:io';

void main() async {
  final file = File('lib/features/dashboard/presentation/screens/dashboard_screen.dart');
  List<String> lines = await file.readAsLines();

  for (int i = 0; i < lines.length; i++) {
    // Remove const from Text(l10n...)
    if (lines[i].contains('const Text(l10n')) {
      lines[i] = lines[i].replaceAll('const Text(l10n', 'Text(l10n');
    }
    if (lines[i].contains('child: const Text(')) {
      lines[i] = lines[i].replaceAll('child: const Text(', 'child: Text(');
    }
    if (lines[i].contains('label: const Text(')) {
      lines[i] = lines[i].replaceAll('label: const Text(', 'label: Text(');
    }
    if (lines[i].contains('const Center(') && lines[i].contains('l10n')) {
      lines[i] = lines[i].replaceAll('const Center(', 'Center(');
    }
    
    // Inject l10n
    if (lines[i].contains('Widget build(BuildContext context) {') ||
        (lines[i].contains('Widget _build') && lines[i].contains('BuildContext context'))) {
      if (!lines[i + 1].contains('AppLocalizations.of(context)')) {
        lines.insert(i + 1, '    final l10n = AppLocalizations.of(context)!;');
      }
    }
  }

  await file.writeAsString(lines.join('\n'));
  print('Done!');
}
