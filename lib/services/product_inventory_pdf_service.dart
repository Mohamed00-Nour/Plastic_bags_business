import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/theme/app_theme.dart';
import '../data/models/product_model_new.dart';
import '../features/reports/presentation/widgets/report_preview_dialog.dart';
import 'whatsapp_share_channel.dart';

class ProductInventoryPdfService {
  ProductInventoryPdfService._();

  /// Generate Product Inventory Audit Report PDF (جرد المنتجات والمخزون)
  static Future<Uint8List> generateInventoryAuditPdf({
    required List<ProductModel> products,
    String locale = 'ar',
    bool quantitiesOnly = false,
  }) async {
    final pdf = pw.Document();
    final isArabic = locale == 'ar';
    final dateFmt = DateFormat('yyyy/MM/dd HH:mm');

    final bodyFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final int totalTypes = products.length;
    final int totalUnits = products.fold(0, (acc, p) => acc + p.stockQuantity);
    final double totalCostValue = products.fold(
      0.0,
      (acc, p) => acc + (p.stockQuantity * p.costPrice),
    );
    final double totalRetailValue = products.fold(
      0.0,
      (acc, p) => acc + (p.stockQuantity * p.price),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (pw.Context context) {
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
                                ? 'تقرير جرد كميات المنتجات'
                                : 'Stock Quantities Audit')
                            : (isArabic
                                ? 'تقرير جرد المنتجات والمخزون الشامل'
                                : 'Full Inventory Audit Report'),
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 22,
                          color: PdfColor.fromHex('#4338CA'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Mr. John - Store Management System',
                        style: pw.TextStyle(
                          font: bodyFont,
                          fontSize: 10,
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
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              // Summary Stats Box
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
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
                          isArabic ? 'عدد الأصناف' : 'Total Items',
                          style: pw.TextStyle(
                            font: bodyFont,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '$totalTypes',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 14,
                            color: PdfColor.fromHex('#4338CA'),
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          isArabic ? 'إجمالي الكميات' : 'Total Stock Units',
                          style: pw.TextStyle(
                            font: bodyFont,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '$totalUnits',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 14,
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
                                ? 'قيمة المخزون بالتكلفة'
                                : 'Inventory Cost Value',
                            style: pw.TextStyle(
                              font: bodyFont,
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '\$${totalCostValue.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 14,
                              color: PdfColor.fromHex('#F59E0B'),
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            isArabic
                                ? 'قيمة المخزون بالبيع'
                                : 'Inventory Retail Value',
                            style: pw.TextStyle(
                              font: bodyFont,
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '\$${totalRetailValue.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 14,
                              color: PdfColor.fromHex('#6366F1'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Inventory Table
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                headerStyle: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#4338CA'),
                ),
                cellStyle: pw.TextStyle(font: bodyFont, fontSize: 9),
                cellAlignment: pw.Alignment.center,
                headers:
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
                        ],
                data: List.generate(products.length, (index) {
                  final p = products[index];
                  if (quantitiesOnly) {
                    return [
                      '${index + 1}',
                      p.name,
                      p.size.isEmpty ? '-' : p.size,
                      '${p.stockQuantity}',
                    ];
                  }
                  final totalCost = p.stockQuantity * p.costPrice;
                  final totalRetail = p.stockQuantity * p.price;
                  return [
                    '${index + 1}',
                    p.name,
                    p.size.isEmpty ? '-' : p.size,
                    '${p.stockQuantity}',
                    '\$${p.costPrice.toStringAsFixed(2)}',
                    '\$${p.price.toStringAsFixed(2)}',
                    '\$${totalCost.toStringAsFixed(2)}',
                    '\$${totalRetail.toStringAsFixed(2)}',
                  ];
                }),
              ),

              pw.SizedBox(height: 16),
              pw.Spacer(),

              // Branding & Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'برمجة شركة easy app - 01126697513',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 10,
                        color: PdfColor.fromHex('#4338CA'),
                      ),
                    ),
                  ],
                ),
              ),
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    isArabic
                        ? 'تم إنشاء التقرير آلياً'
                        : 'Automated Inventory Audit',
                    style: pw.TextStyle(
                      font: bodyFont,
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Page 1 of 1',
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
      ),
    );

    return pdf.save();
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
                  isArabic ? 'نوع تقرير جرد المنتجات' : 'Select Stock Audit Type',
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

      showModalBottomSheet(
        context: pageContext,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (bCtx) {
          return Directionality(
            textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
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
                                  ? 'إجمالي الأصناف: ${products.length} • إجمالي الكميات: ${products.fold(0, (acc, p) => acc + p.stockQuantity)}'
                                  : 'Total Items: ${products.length} • Total Stock: ${products.fold(0, (acc, p) => acc + p.stockQuantity)}',
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
