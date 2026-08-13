import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/order_model.dart';

class OrderExportService {
  OrderExportService._();

  static Future<Uint8List> generatePdf(
    OrderModel order, {
    String locale = 'en',
  }) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('MMM dd, yyyy HH:mm');
    final isArabic = locale == 'ar';

    final headerFont = await PdfGoogleFonts.cairoSemiBold();
    final bodyFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final labelStyle = pw.TextStyle(
      font: bodyFont,
      fontSize: 10,
      color: PdfColors.grey700,
    );
    final valueStyle = pw.TextStyle(font: headerFont, fontSize: 11);
    final tableHeaderStyle = pw.TextStyle(
      font: boldFont,
      fontSize: 10,
      color: PdfColors.white,
    );
    final tableCellStyle = pw.TextStyle(font: bodyFont, fontSize: 10);
    final direction = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: direction,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: isArabic
                ? pw.CrossAxisAlignment.end
                : pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'تفاصيل الطلب',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 18,
                          color: PdfColor.fromHex('#6366F1'),
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        '#${order.id.substring(0, 8).toUpperCase()}',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 16,
                          color: PdfColor.fromHex('#6366F1'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        dateFmt.format(order.createdAt),
                        style: labelStyle,
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey300, thickness: 1),
              pw.SizedBox(height: 16),

              // Order info grid
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfInfoRow(
                          'المحل',
                          order.shopName,
                          labelStyle,
                          valueStyle,
                        ),
                        pw.SizedBox(height: 8),
                        _pdfInfoRow(
                          'الحالة',
                          _statusLabel(order.status, true),
                          labelStyle,
                          valueStyle,
                        ),
                        if (order.approvedBy != null) ...[
                          pw.SizedBox(height: 8),
                          _pdfInfoRow(
                            'تمت الموافقة بواسطة',
                            order.approvedBy!,
                            labelStyle,
                            valueStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (order.createdBy.isNotEmpty) ...[
                          _pdfInfoRow(
                            'أنشئ بواسطة',
                            order.createdBy,
                            labelStyle,
                            valueStyle,
                          ),
                          pw.SizedBox(height: 8),
                        ],
                        if (order.modifiedBy.isNotEmpty) ...[
                          _pdfInfoRow(
                            'عُدل بواسطة',
                            order.modifiedBy,
                            labelStyle,
                            valueStyle,
                          ),
                          pw.SizedBox(height: 8),
                        ],
                        if (order.notes != null && order.notes!.isNotEmpty)
                          _pdfInfoRow(
                            'ملاحظات',
                            order.notes!,
                            labelStyle,
                            valueStyle,
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 24),

              // Items table
              pw.TableHelper.fromTextArray(
                headerDirection: pw.TextDirection.rtl,
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#6366F1'),
                  borderRadius: pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(6),
                    topRight: pw.Radius.circular(6),
                  ),
                ),
                headerStyle: tableHeaderStyle,
                headerAlignment: pw.Alignment.centerLeft,
                cellStyle: tableCellStyle,
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                headerPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                oddRowDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                ),
                border: pw.TableBorder(
                  left: const pw.BorderSide(color: PdfColors.grey300),
                  right: const pw.BorderSide(color: PdfColors.grey300),
                  bottom: const pw.BorderSide(color: PdfColors.grey300),
                  horizontalInside:
                      const pw.BorderSide(color: PdfColors.grey200),
                ),
                headers: ['المجموع', 'سعر الوحدة', 'الكمية', 'الحجم', 'المنتج', '#'],
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FixedColumnWidth(40),
                  4: const pw.FlexColumnWidth(1.5),
                  5: const pw.FlexColumnWidth(1.5),
                },
                data: order.items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final row = [
                    '${i + 1}',
                    item.productName,
                    item.productSize,
                    '${item.quantity}',
                    '\$${item.unitPrice.toStringAsFixed(2)}',
                    '\$${item.total.toStringAsFixed(2)}',
                  ];
                  return row.reversed.toList();
                }).toList(),
              ),

              pw.SizedBox(height: 16),

              // Total
              pw.Container(
                alignment: pw.Alignment.centerLeft,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F1F5F9'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      'الإجمالي:  ',
                      style: pw.TextStyle(font: headerFont, fontSize: 14),
                    ),
                    pw.Text(
                      '\$${order.totalPrice.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 18,
                        color: PdfColor.fromHex('#6366F1'),
                      ),
                    ),
                  ],
                ),
              ),

              if (order.rejectionReason != null &&
                  order.rejectionReason!.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FEF2F2'),
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColor.fromHex('#FECACA')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'سبب الرفض',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 10,
                          color: PdfColor.fromHex('#DC2626'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        order.rejectionReason!,
                        style: pw.TextStyle(font: bodyFont, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],

              pw.SizedBox(height: 14),

              // Easy App Branding right after table/total summary
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'برمجة شركة easy app',
                      style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColor.fromHex('#6366F1')),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '01126697513',
                      style: pw.TextStyle(font: bodyFont, fontSize: 10, color: PdfColors.grey800),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Text(
                'تم إنشاء التقرير آلياً',
                style: pw.TextStyle(
                  font: bodyFont,
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfInfoRow(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: labelStyle),
        pw.SizedBox(height: 2),
        pw.Text(value, style: valueStyle),
      ],
    );
  }

  static String _statusLabel(OrderStatus status, bool isArabic) {
    if (isArabic) {
      switch (status) {
        case OrderStatus.pending:
          return 'قيد الانتظار';
        case OrderStatus.approved:
          return 'تمت الموافقة';
        case OrderStatus.rejected:
          return 'مرفوض';
        case OrderStatus.delivered:
          return 'تم التوصيل';
      }
    }
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.approved:
        return 'Approved';
      case OrderStatus.rejected:
        return 'Rejected';
      case OrderStatus.delivered:
        return 'Delivered';
    }
  }

  /// Print or share the PDF using the printing package's built-in UI.
  static Future<void> printOrSharePdf(
    OrderModel order, {
    String locale = 'en',
  }) async {
    final bytes = await generatePdf(order, locale: locale);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  /// Save the PDF to the Downloads folder and return the file path.
  static Future<String> savePdfToFile(
    OrderModel order, {
    String locale = 'en',
  }) async {
    final bytes = await generatePdf(order, locale: locale);
    final dir = await _getDownloadsDirectory();
    final fileName =
        'Order_${order.id.substring(0, 8)}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Capture a widget painted via a RepaintBoundary as a PNG image.
  static Future<String?> captureWidgetAsImage(
    GlobalKey boundaryKey,
    String orderId,
  ) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final dir = await _getDownloadsDirectory();
      final fileName =
          'Order_${orderId.substring(0, 8)}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final downloads = Directory('$userProfile\\Downloads');
        if (await downloads.exists()) return downloads;
      }
    }
    final dir = await getApplicationDocumentsDirectory();
    return dir;
  }
}
