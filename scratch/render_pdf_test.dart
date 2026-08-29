import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:store_manager/utils/arabic_reshaper.dart';

void main() {
  testWidgets('Render PDF Arabic test', (WidgetTester tester) async {
    final fontData = File('assets/fonts/Amiri-Regular.ttf').readAsBytesSync();
    final ttf = pw.Font.ttf(fontData.buffer.asByteData());

    final pdf = pw.Document();

    final testStr = "شنطة بيبي شفاف 17";
    final reshapedStr = ArabicReshaper.reshape(testStr);
    final reversedReshaped = ArabicReshaper.reshapeAndReverse(testStr);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttf),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Original: $testStr", style: pw.TextStyle(font: ttf, fontSize: 16)),
              pw.SizedBox(height: 10),
              pw.Text("Mode 1: Direct Reshaped (No RTL direction, LTR string):", style: pw.TextStyle(font: ttf, fontSize: 14)),
              pw.Text(reshapedStr, style: pw.TextStyle(font: ttf, fontSize: 20)),
              pw.SizedBox(height: 10),
              pw.Text("Mode 2: Reshaped + Reversed (No RTL direction):", style: pw.TextStyle(font: ttf, fontSize: 14)),
              pw.Text(reversedReshaped, style: pw.TextStyle(font: ttf, fontSize: 20)),
              pw.SizedBox(height: 10),
              pw.Text("Mode 3: Reshaped + textDirection RTL:", style: pw.TextStyle(font: ttf, fontSize: 14)),
              pw.Text(reshapedStr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: ttf, fontSize: 20)),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final outPath = 'G:/VS Flutter projects/John/Mr.Jhon/Mr_John/scratch/test_arabic_modes.png';
    print("PDF byte length: ${bytes.length}");

    await for (final page in Printing.raster(bytes, pages: [0], dpi: 150)) {
      final pngBytes = await page.toPng();
      await File(outPath).writeAsBytes(pngBytes);
      print("Saved PNG to $outPath, size: ${pngBytes.length}");
      break;
    }
  });
}
