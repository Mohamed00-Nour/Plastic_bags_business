import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class ReportPreviewDialog extends StatelessWidget {
  final String title;
  final Future<Uint8List> Function(PdfPageFormat) buildPdf;

  const ReportPreviewDialog({
    super.key,
    required this.title,
    required this.buildPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: PdfPreview(
          build: buildPdf,
          allowPrinting: true,
          allowSharing: true,
          canChangePageFormat: false,
          canChangeOrientation: false,
          pdfFileName: '${title.replaceAll(' ', '_')}.pdf',
        ),
      ),
    );
  }
}
