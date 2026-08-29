import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../lib/utils/arabic_reshaper.dart';

void main() async {
  final fontData = File('assets/fonts/Amiri-Regular.ttf').readAsBytesSync();
  final ttf = pw.Font.ttf(fontData.buffer.asByteData());

  final pdf = pw.Document();

  final testStr = "شنطة بيبي شفاف 17";
  final reshapedStr = ArabicReshaper.reshape(testStr);

  print("Original: $testStr");
  print("Reshaped runes: ${reshapedStr.runes.map((r) => r.toRadixString(16)).toList()}");

  pdf.addPage(
    pw.Page(
      theme: pw.ThemeData.withFont(base: ttf),
      build: (pw.Context context) {
        return pw.Column(
          children: [
            pw.Text("1. Direct reshaped (LTR direction):"),
            pw.Text(reshapedStr, style: pw.TextStyle(font: ttf, fontSize: 20)),
            pw.SizedBox(height: 10),
            pw.Text("2. Reshaped with RTL direction:"),
            pw.Text(reshapedStr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: ttf, fontSize: 20)),
            pw.SizedBox(height: 10),
            pw.Text("3. Reshaped and reversed (LTR direction):"),
            pw.Text(reshapedStr.split('').reversed.join(''), style: pw.TextStyle(font: ttf, fontSize: 20)),
          ],
        );
      },
    ),
  );

  final file = File('scratch/test_output.pdf');
  await file.writeAsBytes(await pdf.save());
  print("Saved PDF to ${file.path}");
}
