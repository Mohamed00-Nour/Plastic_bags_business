import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../core/theme/app_theme.dart';
import '../core/utils/quantity_formatter.dart';
import '../data/models/product_model_new.dart';
import '../features/reports/presentation/widgets/report_preview_dialog.dart';
import '../utils/arabic_reshaper.dart';
import 'whatsapp_share_channel.dart';

class ProductInventoryPdfService {
  ProductInventoryPdfService._();

  /// Helper to reshape and reverse Arabic text for PDF rendering
  static String _r(String text) => ArabicReshaper.reshapeAndReverse(text);

  /// Generate Product Inventory Audit Report PDF (جرد المنتجات والمخزون)
  static Future<Uint8List> generateInventoryAuditPdf({
    required List<ProductModel> products,
    String locale = 'ar',
    bool quantitiesOnly = false,
  }) async {
    // Load Amiri static TTF font for complete Arabic Presentation Forms support.
    final regularData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
    final bodyFont = pw.Font.ttf(regularData);
    final boldFont = pw.Font.ttf(boldData);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: bodyFont, bold: boldFont),
    );
    final isArabic = locale == 'ar';
    final dateFmt = DateFormat('yyyy/MM/dd HH:mm');

    final int totalTypes = products.length;
    final double totalUnits = products.fold(
      0.0,
      (acc, p) => acc + p.stockQuantity,
    );
    final double totalCostValue = products.fold(
      0.0,
      (acc, p) => acc + (p.stockQuantity * p.costPrice),
    );
    final double totalRetailValue = products.fold(
      0.0,
      (acc, p) => acc + (p.stockQuantity * p.price),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Banner
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        quantitiesOnly
                            ? (isArabic
                                ? _r('تقرير جرد كميات المنتجات')
                                : 'Stock Quantities Audit')
                            : (isArabic
                                ? _r('تقرير جرد المنتجات والمخزون الشامل')
                                : 'Full Inventory Audit Report'),
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 18,
                          color: PdfColor.fromHex('#4338CA'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Mr. John - Store Management System',
                        style: pw.TextStyle(
                          font: bodyFont,
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        dateFmt.format(DateTime.now()),
                        style: pw.TextStyle(
                          font: bodyFont,
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    isArabic
                        ? _r('برمجة شركة easy app - 01126697513')
                        : 'Developed by Easy App - 01126697513',
                    style: pw.TextStyle(
                      font: bodyFont,
                      fontSize: 8,
                      color: PdfColor.fromHex('#4338CA'),
                    ),
                  ),
                  pw.Text(
                    isArabic
                        ? '${_r('صفحة')} ${context.pageNumber} ${_r('من')} ${context.pagesCount}'
                        : 'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(
                      font: bodyFont,
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build:
            (pw.Context context) => [
              // Summary Stats Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                margin: const pw.EdgeInsets.only(bottom: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F3F4F6'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          isArabic ? _r('عدد الأصناف') : 'Total Items',
                          style: pw.TextStyle(
                            font: bodyFont,
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          '$totalTypes',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 13,
                            color: PdfColor.fromHex('#4338CA'),
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          isArabic ? _r('إجمالي الكميات') : 'Total Stock Units',
                          style: pw.TextStyle(
                            font: bodyFont,
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          formatQuantity(totalUnits),
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 13,
                            color: PdfColor.fromHex('#10B981'),
                          ),
                        ),
                      ],
                    ),
                    if (!quantitiesOnly) ...[
                      pw.Column(
                        children: [
                          pw.Text(
                            isArabic
                                ? _r('قيمة المخزون بالتكلفة')
                                : 'Inventory Cost Value',
                            style: pw.TextStyle(
                              font: bodyFont,
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '\$${totalCostValue.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 13,
                              color: PdfColor.fromHex('#F59E0B'),
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            isArabic
                                ? _r('قيمة المخزون بالبيع')
                                : 'Inventory Retail Value',
                            style: pw.TextStyle(
                              font: bodyFont,
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '\$${totalRetailValue.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 13,
                              color: PdfColor.fromHex('#6366F1'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Build headers and rows
              _buildInventoryTable(
                products: products,
                isArabic: isArabic,
                quantitiesOnly: quantitiesOnly,
                bodyFont: bodyFont,
                boldFont: boldFont,
              ),
            ],
      ),
    );

    return pdf.save();
  }

  /// Build an inventory table using explicit pw.Table
  static pw.Widget _buildInventoryTable({
    required List<ProductModel> products,
    required bool isArabic,
    required bool quantitiesOnly,
    required pw.Font bodyFont,
    required pw.Font boldFont,
  }) {
    final border = pw.TableBorder.all(color: PdfColors.grey300, width: 0.5);
    final headerBg = PdfColor.fromHex('#4338CA');

    // Column widths
    final colWidths =
        quantitiesOnly
            ? <int, pw.TableColumnWidth>{
              0: const pw.FlexColumnWidth(0.8),
              1: const pw.FlexColumnWidth(4.5),
              2: const pw.FlexColumnWidth(2.2),
              3: const pw.FlexColumnWidth(2.2),
            }
            : <int, pw.TableColumnWidth>{
              0: const pw.FlexColumnWidth(0.7),
              1: const pw.FlexColumnWidth(3.5),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(1.4),
              4: const pw.FlexColumnWidth(1.4),
              5: const pw.FlexColumnWidth(1.4),
              6: const pw.FlexColumnWidth(1.8),
              7: const pw.FlexColumnWidth(1.8),
            };

    // Helper to build a header cell
    pw.Widget headerCell(String text) {
      return pw.Container(
        color: headerBg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: pw.Text(
          isArabic ? _r(text) : text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 9,
            color: PdfColors.white,
          ),
        ),
      );
    }

    // Helper to build a data cell
    pw.Widget dataCell(String text, {bool even = false}) {
      return pw.Container(
        color: even ? PdfColor.fromHex('#F8FAFC') : PdfColors.white,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Text(
          isArabic ? _r(text) : text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: bodyFont, fontSize: 8.5),
        ),
      );
    }

    final List<String> headers =
        quantitiesOnly
            ? [
              '#',
              isArabic ? 'اسم المنتج' : 'Product Name',
              isArabic ? 'المقاس' : 'Size',
              isArabic ? 'الكمية المتوفرة' : 'Stock Quantity',
            ]
            : [
              '#',
              isArabic ? 'اسم المنتج' : 'Product Name',
              isArabic ? 'المقاس' : 'Size',
              isArabic ? 'الكمية' : 'Stock',
              isArabic ? 'التكلفة' : 'Cost',
              isArabic ? 'سعر البيع' : 'Price',
              isArabic ? 'إجمالي التكلفة' : 'Total Cost',
              isArabic ? 'إجمالي البيع' : 'Total Retail',
            ];

    final headerRow = pw.TableRow(children: headers.map(headerCell).toList());

    final dataRows = List.generate(products.length, (i) {
      final p = products[i];
      final even = i.isEven;
      if (quantitiesOnly) {
        return pw.TableRow(
          children: [
            dataCell('${i + 1}', even: even),
            dataCell(p.name, even: even),
            dataCell(p.size.isEmpty ? '-' : p.size, even: even),
            dataCell(formatQuantity(p.stockQuantity), even: even),
          ],
        );
      }
      final totalCost = p.stockQuantity * p.costPrice;
      final totalRetail = p.stockQuantity * p.price;
      return pw.TableRow(
        children: [
          dataCell('${i + 1}', even: even),
          dataCell(p.name, even: even),
          dataCell(p.size.isEmpty ? '-' : p.size, even: even),
          dataCell(formatQuantity(p.stockQuantity), even: even),
          dataCell('\$${p.costPrice.toStringAsFixed(2)}', even: even),
          dataCell('\$${p.price.toStringAsFixed(2)}', even: even),
          dataCell('\$${totalCost.toStringAsFixed(2)}', even: even),
          dataCell('\$${totalRetail.toStringAsFixed(2)}', even: even),
        ],
      );
    });

    return pw.Table(
      border: border,
      columnWidths: colWidths,
      children: [headerRow, ...dataRows],
    );
  }

  /// Selection Dialog to choose between Full Audit and Quantities Only
  static Future<void> showInventoryAuditSelectionDialog({
    required BuildContext context,
    required List<ProductModel> products,
    String locale = 'ar',
  }) async {
    final isArabic = locale == 'ar';

    return showDialog(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.inventory_rounded,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 10),
                Text(
                  isArabic
                      ? 'نوع تقرير جرد المنتجات'
                      : 'Select Stock Audit Type',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isArabic
                      ? 'يرجى تحديد تفاصيل البيانات المطلوبة في تقرير جرد المخزون:'
                      : 'Please choose the details to include in your stock audit report:',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Option 1: Full Audit (All Columns)
                Card(
                  elevation: 0,
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.2,
                      ),
                      child: const Icon(
                        Icons.table_chart_rounded,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    title: Text(
                      isArabic
                          ? 'جرد شامل لجميع البيانات والأسعار'
                          : 'Full Audit (All Columns & Prices)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isArabic
                          ? 'يتضمن اسم المنتج، المقاس، الكمية، التكلفة، البيع، والإجمالي'
                          : 'Includes Product, Size, Stock, Cost, Price & Total Values',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(dialogCtx);
                      showInventoryActionDialog(
                        context: context,
                        products: products,
                        locale: locale,
                        quantitiesOnly: false,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Option 2: Quantities Only
                Card(
                  elevation: 0,
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: Color(0xFF10B981),
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(
                        0xFF10B981,
                      ).withValues(alpha: 0.2),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    title: Text(
                      isArabic
                          ? 'جرد الكميات والأعداد فقط'
                          : 'Quantities Only (Stock Count)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isArabic
                          ? 'يتضمن اسم المنتج، المقاس، وكمية المخزون المتوفرة بدون أسعار'
                          : 'Includes Product, Size & Stock Quantity only (No Prices)',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(dialogCtx);
                      showInventoryActionDialog(
                        context: context,
                        products: products,
                        locale: locale,
                        quantitiesOnly: true,
                      );
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show Action Sheet Modal for Inventory Audit PDF (WhatsApp, Open/Save, Print)
  static Future<void> showInventoryActionDialog({
    required BuildContext context,
    required List<ProductModel> products,
    String locale = 'ar',
    bool quantitiesOnly = false,
  }) async {
    final isArabic = locale == 'ar';
    final pageContext = context;

    // Show non-dismissible loading dialog
    BuildContext? loadingContext;
    showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder: (lCtx) {
        loadingContext = lCtx;
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  isArabic
                      ? 'جاري إنشاء تقرير جرد المنتجات...'
                      : 'Generating inventory audit PDF...',
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final pdfBytes = await generateInventoryAuditPdf(
        products: products,
        locale: locale,
        quantitiesOnly: quantitiesOnly,
      );

      if (loadingContext != null && loadingContext!.mounted) {
        Navigator.pop(loadingContext!);
      }

      if (!pageContext.mounted) return;

      final totalStock = products.fold<double>(
        0.0,
        (acc, p) => acc + p.stockQuantity,
      );

      showModalBottomSheet(
        context: pageContext,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (bCtx) {
          return Directionality(
            textDirection:
                isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_rounded,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'تقرير جرد المنتجات والمخزون'
                                  : 'Inventory Audit Report',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              isArabic
                                  ? 'إجمالي الأصناف: ${products.length} • إجمالي الكميات: ${formatQuantity(totalStock)}'
                                  : 'Total Items: ${products.length} • Total Stock: ${formatQuantity(totalStock)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Option 1: Share via WhatsApp PDF
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.share_rounded,
                        color: Colors.green,
                      ),
                    ),
                    title: Text(
                      isArabic
                          ? 'مشاركة تقرير الجرد (PDF)'
                          : 'Share Audit Report (PDF)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isArabic
                          ? 'إرسال ملف PDF الجرد مباشرة عبر الواتساب'
                          : 'Share PDF inventory report via WhatsApp',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(bCtx);
                      try {
                        final tempDir = await getTemporaryDirectory();
                        final filePath =
                            '${tempDir.path}/inventory_audit_${DateTime.now().millisecondsSinceEpoch}.pdf';
                        final file = File(filePath);
                        await file.writeAsBytes(pdfBytes);

                        await WhatsappShareChannel.shareImages(
                          phoneDigits: '',
                          imagePaths: [filePath],
                          caption:
                              isArabic
                                  ? 'تقرير جرد المنتجات والمخزون'
                                  : 'Inventory Audit Report',
                        );
                      } catch (e) {
                        if (pageContext.mounted) {
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            SnackBar(content: Text('Error sharing PDF: $e')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // Option 2: Save & Open PDF File
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.blue,
                      ),
                    ),
                    title: Text(
                      isArabic ? 'عرض وحفظ ملف PDF' : 'View & Save PDF File',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isArabic
                          ? 'فتح ملف PDF للمعاينة والطباعة أو التنزيل'
                          : 'Preview, download or open PDF file',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(bCtx);
                      showDialog(
                        context: pageContext,
                        builder:
                            (ctx) => ReportPreviewDialog(
                              title:
                                  isArabic
                                      ? 'تقرير جرد المنتجات'
                                      : 'Inventory Audit Report',
                              buildPdf: (format) async => pdfBytes,
                            ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // Option 3: Direct Print Report
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.print_rounded,
                        color: Colors.purple,
                      ),
                    ),
                    title: Text(
                      isArabic ? 'طباعة تقرير الجرد' : 'Print Inventory Audit',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isArabic
                          ? 'إرسال الملف مباشرة للطابعة'
                          : 'Send file to system printer',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(bCtx);
                      await Printing.layoutPdf(
                        onLayout: (PdfPageFormat format) async => pdfBytes,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (loadingContext != null && loadingContext!.mounted) {
        Navigator.pop(loadingContext!);
      }
      if (pageContext.mounted) {
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(
            content: Text('Error generating audit report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
