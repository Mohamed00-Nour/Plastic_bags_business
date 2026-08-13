import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/theme/app_theme.dart';
import '../widgets/invoice_action_dialog.dart';
import 'client_invoice_balance_sync_service.dart';
import 'whatsapp_invoice_share_service.dart';
import 'whatsapp_share_channel.dart';

class ClientStatementPdfService {
  ClientStatementPdfService._();

  /// Generate Client Account Statement PDF (Bilingual support for AR/EN based on locale)
  static Future<Uint8List> generateClientStatementPdf({
    required Map<String, dynamic> clientData,
    required List<ClientBalanceRecord> records,
    String locale = 'ar',
  }) async {
    final pdf = pw.Document();
    final isArabic = locale == 'ar';
    final dateFmt = DateFormat('yyyy/MM/dd HH:mm');

    final bodyFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final direction = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final clientName =
        clientData['name'] ?? (isArabic ? 'عميل بدون اسم' : 'Unnamed Client');
    final clientPhone = clientData['phone'] ?? '';
    final clientAddress = clientData['address'] ?? '';
    final currentBalance = (clientData['balance'] ?? 0.0).toDouble();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: direction,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Title
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'كشف حساب عميل',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 20,
                          color: PdfColor.fromHex('#4338CA'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'تاريخ التقرير: ${dateFmt.format(DateTime.now())}',
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
              pw.Divider(color: PdfColors.grey300, thickness: 1),
              pw.SizedBox(height: 12),

              // Client Info Section
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'اسم العميل: $clientName',
                          style: pw.TextStyle(font: boldFont, fontSize: 12),
                        ),
                        if (clientPhone.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'الهاتف: $clientPhone',
                            style: pw.TextStyle(font: bodyFont, fontSize: 10),
                          ),
                        ],
                        if (clientAddress.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'العنوان: $clientAddress',
                            style: pw.TextStyle(font: bodyFont, fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: pw.BoxDecoration(
                        color:
                            currentBalance > 0
                                ? PdfColor.fromHex('#FEF2F2')
                                : PdfColor.fromHex('#ECFDF5'),
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(
                          color:
                              currentBalance > 0
                                  ? PdfColor.fromHex('#FCA5A5')
                                  : PdfColor.fromHex('#6EE7B7'),
                        ),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'الرصيد المستحق الحالي',
                            style: pw.TextStyle(
                              font: bodyFont,
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '\$${currentBalance.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 16,
                              color:
                                  currentBalance > 0
                                      ? PdfColor.fromHex('#DC2626')
                                      : PdfColor.fromHex('#059669'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Balance Movement Table
              pw.TableHelper.fromTextArray(
                headerDirection: direction,
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#4338CA'),
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(6),
                    topRight: pw.Radius.circular(6),
                  ),
                ),
                headerStyle: pw.TextStyle(
                  font: boldFont,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
                cellStyle: pw.TextStyle(font: bodyFont, fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                headerPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                oddRowDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F1F5F9'),
                ),
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                headers: [
                  'تاريخ',
                  'النوع',
                  'رقم المستند',
                  'المبلغ',
                  'الرصيد المتبقي',
                ],
                data:
                    records.map((rec) {
                      return [
                        DateFormat('yyyy/MM/dd HH:mm').format(rec.timestamp),
                        _formatRecordType(rec.type, isArabic, invoiceNumber: rec.invoiceNumber),
                        rec.invoiceNumber.isEmpty ? '-' : rec.invoiceNumber,
                        '\$${rec.amount.toStringAsFixed(2)}',
                        '\$${rec.balanceAfter.toStringAsFixed(2)}',
                      ];
                    }).toList(),
              ),

              pw.SizedBox(height: 12),

              // Easy App Branding right after table
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'برمجة شركة easy app',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 11,
                        color: PdfColor.fromHex('#4338CA'),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '01126697513',
                      style: pw.TextStyle(
                        font: bodyFont,
                        fontSize: 10,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'تم إنشاء التقرير آلياً',
                    style: pw.TextStyle(
                      font: bodyFont,
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'الصفحة 1 من 1',
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

  /// Generate Sales Invoice Printable Receipt PDF
  static Future<Uint8List> generateSalesInvoicePdf({
    required Map<String, dynamic> invoiceData,
    String locale = 'ar',
  }) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('yyyy/MM/dd HH:mm');

    final headerFont = await PdfGoogleFonts.cairoSemiBold();
    final bodyFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final direction = pw.TextDirection.rtl;

    final invoiceNumber = invoiceData['invoiceNumber'] ?? 'INV-000';
    final clientName = invoiceData['clientName'] ?? 'عميل نقدي';
    final paymentMethod = invoiceData['paymentMethod'] ?? 'نقدي';
    final rawDate = invoiceData['date'] ?? invoiceData['createdAt'];
    final parsedDate = ClientInvoiceBalanceSyncService.parseInvoiceDate(
      rawDate,
    );
    final items =
        (invoiceData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final subtotal = (invoiceData['subtotal'] ?? 0.0).toDouble();
    final discount = (invoiceData['discount'] ?? 0.0).toDouble();
    final totalAmount = (invoiceData['totalAmount'] ?? 0.0).toDouble();
    final paidAmount = (invoiceData['paidAmount'] ?? 0.0).toDouble();
    final remainingAmount = (invoiceData['remainingAmount'] ?? 0.0).toDouble();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: direction,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Invoice Top Banner
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'فاتورة مبيعات',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 22,
                          color: PdfColor.fromHex('#4338CA'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '#$invoiceNumber',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 14,
                          color: PdfColor.fromHex('#6366F1'),
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        dateFmt.format(parsedDate),
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

              // Details Grid
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'العميل: $clientName',
                        style: pw.TextStyle(font: boldFont, fontSize: 11),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'طريقة الدفع: $paymentMethod',
                        style: pw.TextStyle(font: bodyFont, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // Items Table
              pw.TableHelper.fromTextArray(
                headerDirection: direction,
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#4338CA'),
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(6),
                    topRight: pw.Radius.circular(6),
                  ),
                ),
                headerStyle: pw.TextStyle(
                  font: boldFont,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
                cellStyle: pw.TextStyle(font: bodyFont, fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                headers: ['المنتج', 'الكمية', 'سعر الوحدة', 'الإجمالي'],
                data:
                    items.map((item) {
                      final name = item['productName'] ?? '';
                      final qty = item['quantity'] ?? 0;
                      final price = (item['price'] ?? 0.0).toDouble();
                      final total = (item['total'] ?? (qty * price)).toDouble();
                      return [
                        name,
                        '$qty',
                        '\$${price.toStringAsFixed(2)}',
                        '\$${total.toStringAsFixed(2)}',
                      ];
                    }).toList(),
              ),

              pw.SizedBox(height: 14),

              // Calculations Box
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    children: [
                      _buildSummaryRow('المجموع الفرعي', subtotal, bodyFont),
                      if (discount > 0)
                        _buildSummaryRow('الخصم', -discount, bodyFont),
                      pw.Divider(color: PdfColors.grey300),
                      _buildSummaryRow(
                        'الإجمالي النهائي',
                        totalAmount,
                        boldFont,
                        isPrimary: true,
                      ),
                      _buildSummaryRow('المبلغ المدفوع', paidAmount, bodyFont),
                      _buildSummaryRow(
                        'المتبقي',
                        remainingAmount,
                        boldFont,
                        colorHex: '#DC2626',
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 14),

              // Easy App Branding right after calculations box
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'شكراً لتعاملكم معنا!',
                      style: pw.TextStyle(
                        font: headerFont,
                        fontSize: 11,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'برمجة شركة easy app',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 11,
                        color: PdfColor.fromHex('#4338CA'),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '01126697513',
                      style: pw.TextStyle(
                        font: bodyFont,
                        fontSize: 10,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(
    String label,
    double amount,
    pw.Font font, {
    bool isPrimary = false,
    String? colorHex,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: isPrimary ? 10 : 9),
          ),
          pw.Text(
            '\$${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              font: font,
              fontSize: isPrimary ? 11 : 9,
              color:
                  colorHex != null
                      ? PdfColor.fromHex(colorHex)
                      : (isPrimary
                          ? PdfColor.fromHex('#4338CA')
                          : PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRecordType(String type, bool isArabic, {String invoiceNumber = ''}) {
    if (isArabic) {
      switch (type) {
        case 'opening':
          return 'رصيد افتتاحي';
        case 'manual_debt':
        case 'debt':
          return 'إضافة مديونية';
        case 'sales_invoice':
          return invoiceNumber.isNotEmpty ? 'فاتورة مبيعات #$invoiceNumber' : 'فاتورة مبيعات';
        case 'sales_return':
          return invoiceNumber.isNotEmpty ? 'مرتجع فاتورة #$invoiceNumber' : 'مرتجع مبيعات';
        case 'payment':
          return invoiceNumber.isNotEmpty ? 'تحصيل من فاتورة #$invoiceNumber' : 'تحصيل دفعة';
        case 'cancellation':
          return 'إلغاء فاتورة';
        default:
          return 'حركة رصيد';
      }
    } else {
      switch (type) {
        case 'opening':
          return 'Opening Balance';
        case 'manual_debt':
        case 'debt':
          return 'Add Debt';
        case 'sales_invoice':
          return invoiceNumber.isNotEmpty ? 'Invoice #$invoiceNumber' : 'Sales Invoice';
        case 'sales_return':
          return invoiceNumber.isNotEmpty ? 'Return #$invoiceNumber' : 'Sales Return';
        case 'payment':
          return invoiceNumber.isNotEmpty ? 'Payment for #$invoiceNumber' : 'Payment';
        case 'cancellation':
          return 'Invoice Cancellation';
        default:
          return 'Transaction';
      }
    }
  }

  /// Print or Share Client Statement PDF
  static Future<void> printOrShareClientStatement({
    required Map<String, dynamic> clientData,
    required List<ClientBalanceRecord> records,
    String locale = 'ar',
  }) async {
    final pdfBytes = await generateClientStatementPdf(
      clientData: clientData,
      records: records,
      locale: locale,
    );
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }

  /// Print or Share Sales Invoice PDF
  static Future<void> printOrShareSalesInvoice({
    required Map<String, dynamic> invoiceData,
    String locale = 'ar',
  }) async {
    final pdfBytes = await generateSalesInvoicePdf(
      invoiceData: invoiceData,
      locale: locale,
    );
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }

  /// Display Action Dialog (WhatsApp, Print, View, Save) for Sales Invoice
  static Future<void> showSalesInvoiceActionDialog({
    required BuildContext context,
    required Map<String, dynamic> invoiceData,
    String locale = 'ar',
  }) async {
    final pdfBytes = await generateSalesInvoicePdf(
      invoiceData: invoiceData,
      locale: locale,
    );
    if (!context.mounted) return;
    await InvoiceActionDialog.show(
      context: context,
      invoiceData: invoiceData,
      pdfBytes: pdfBytes,
      locale: locale,
      isSalesInvoice: true,
    );
  }

  /// Display Action Dialog (WhatsApp, Open/Save PDF, Print) for Client Statement
  static Future<void> showStatementActionDialog({
    required BuildContext context,
    required Map<String, dynamic> clientData,
    required List<ClientBalanceRecord> records,
    String locale = 'ar',
  }) async {
    debugPrint('=== DEBUG STATEMENT PDF GENERATION ===');
    debugPrint('Client Data: $clientData');
    debugPrint('Records Count: ${records.length}');

    final pdfBytes = await generateClientStatementPdf(
      clientData: clientData,
      records: records,
      locale: locale,
    );

    debugPrint('Generated PDF Bytes Length: ${pdfBytes.length}');

    if (!context.mounted) {
      debugPrint('Context no longer mounted after PDF generation');
      return;
    }

    final clientName = clientData['name']?.toString() ?? 'عميل';
    final rawPhone = clientData['phone']?.toString() ?? '';
    final targetPhone = WhatsappInvoiceShareService.cleanPhoneDigits(rawPhone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primaryColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'كشف حساب العميل: $clientName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'اختر طريقة تصدير أو مشاركة كشف الحساب (PDF)',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),

              // Option 1: Share via WhatsApp
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF25D366),
                  child: Icon(Icons.share_rounded, color: Colors.white),
                ),
                title: const Text('مشاركة كشف الحساب عبر واتساب'),
                subtitle: Text(
                  targetPhone.isNotEmpty
                      ? 'إرسال مستند PDF مباشرة للعميل ($targetPhone)'
                      : 'مشاركة مستند PDF واختيار المستلم من الواتساب',
                ),
                onTap: () async {
                  Navigator.of(bContext).pop();
                  final cleanName = clientName.replaceAll(RegExp(r'[^\w\s-]'), '_');
                  final filename = 'Statement_$cleanName.pdf';

                  try {
                    final tempDir = await getTemporaryDirectory();
                    final pdfFile = File('${tempDir.path}/$filename');
                    await pdfFile.writeAsBytes(pdfBytes);

                    final shared = await WhatsappShareChannel.shareImages(
                      phoneDigits: targetPhone,
                      imagePaths: [pdfFile.path],
                      caption: 'كشف حساب العميل: $clientName',
                    );
                    if (shared) return;
                  } catch (e) {
                    debugPrint('Statement PDF share error: $e');
                  }

                  await Printing.sharePdf(
                    bytes: pdfBytes,
                    filename: filename,
                    subject: 'كشف حساب العميل: $clientName',
                  );
                },
              ),
              const Divider(),

              // Option 2: Save & Open PDF File
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.file_open_rounded, color: Colors.white),
                ),
                title: const Text('حفظ وفتح مستند PDF'),
                subtitle: const Text('معاينة المستند أو تنزيله على الجهاز'),
                onTap: () async {
                  Navigator.of(bContext).pop();
                  final cleanName = clientName.replaceAll(RegExp(r'[^\w\s-]'), '_');
                  final filename = 'Statement_$cleanName.pdf';

                  try {
                    Directory? downloadsDir;
                    try { downloadsDir = await getDownloadsDirectory(); } catch (_) {}
                    downloadsDir ??= await getTemporaryDirectory();
                    final pdfFile = File('${downloadsDir.path}/$filename');
                    await pdfFile.writeAsBytes(pdfBytes);
                  } catch (_) {}

                  await Printing.layoutPdf(
                    onLayout: (_) => pdfBytes,
                    name: filename,
                  );
                },
              ),
              const Divider(),

              // Option 3: Print Statement
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.print_rounded, color: Colors.white),
                ),
                title: const Text('طباعة كشف الحساب'),
                subtitle: const Text('إرسال المستند مباشرة إلى الطابعة'),
                onTap: () async {
                  Navigator.of(bContext).pop();
                  await Printing.layoutPdf(onLayout: (_) => pdfBytes);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
