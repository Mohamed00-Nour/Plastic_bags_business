import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'client_invoice_balance_sync_service.dart';

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
    final clientName = clientData['name'] ?? (isArabic ? 'عميل بدون اسم' : 'Unnamed Client');
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
                        isArabic ? 'كشف حساب عميل' : 'Client Account Statement',
                        style: pw.TextStyle(font: boldFont, fontSize: 20, color: PdfColor.fromHex('#4338CA')),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        isArabic ? 'تاريخ التقرير: ${dateFmt.format(DateTime.now())}' : 'Report Date: ${dateFmt.format(DateTime.now())}',
                        style: pw.TextStyle(font: bodyFont, fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Text(
                    "Mr.John ERP",
                    style: pw.TextStyle(font: boldFont, fontSize: 18, color: PdfColors.grey800),
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
                          '${isArabic ? "اسم العميل: " : "Client Name: "}$clientName',
                          style: pw.TextStyle(font: boldFont, fontSize: 12),
                        ),
                        if (clientPhone.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '${isArabic ? "الهاتف: " : "Phone: "}$clientPhone',
                            style: pw.TextStyle(font: bodyFont, fontSize: 10),
                          ),
                        ],
                        if (clientAddress.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '${isArabic ? "العنوان: " : "Address: "}$clientAddress',
                            style: pw.TextStyle(font: bodyFont, fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: currentBalance > 0 ? PdfColor.fromHex('#FEF2F2') : PdfColor.fromHex('#ECFDF5'),
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(
                          color: currentBalance > 0 ? PdfColor.fromHex('#FCA5A5') : PdfColor.fromHex('#6EE7B7'),
                        ),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            isArabic ? 'الرصيد المستحق الحالي' : 'Current Due Balance',
                            style: pw.TextStyle(font: bodyFont, fontSize: 9, color: PdfColors.grey700),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '\$${currentBalance.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 16,
                              color: currentBalance > 0 ? PdfColor.fromHex('#DC2626') : PdfColor.fromHex('#059669'),
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
                headerStyle: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.white),
                cellStyle: pw.TextStyle(font: bodyFont, fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headers: isArabic
                    ? ['تاريخ', 'النوع', 'رقم المستند', 'المبلغ', 'الرصيد المتبقي']
                    : ['Date', 'Type', 'Doc #', 'Amount', 'Balance After'],
                data: records.map((rec) {
                  return [
                    DateFormat('yyyy/MM/dd HH:mm').format(rec.timestamp),
                    _formatRecordType(rec.type, isArabic),
                    rec.invoiceNumber.isEmpty ? '-' : rec.invoiceNumber,
                    '\$${rec.amount.toStringAsFixed(2)}',
                    '\$${rec.balanceAfter.toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    isArabic ? 'تم إنشاء التقرير آلياً عبر نظام Mr.John' : 'Generated automatically by Mr.John ERP',
                    style: pw.TextStyle(font: bodyFont, fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Page 1 of 1',
                    style: pw.TextStyle(font: bodyFont, fontSize: 8, color: PdfColors.grey600),
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
    final isArabic = locale == 'ar';
    final dateFmt = DateFormat('yyyy/MM/dd HH:mm');

    final headerFont = await PdfGoogleFonts.cairoSemiBold();
    final bodyFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final direction = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final invoiceNumber = invoiceData['invoiceNumber'] ?? 'INV-000';
    final clientName = invoiceData['clientName'] ?? (isArabic ? 'عميل نقدي' : 'Cash Client');
    final paymentMethod = invoiceData['paymentMethod'] ?? 'Cash';
    final rawDate = invoiceData['date'] ?? invoiceData['createdAt'];
    final parsedDate = ClientInvoiceBalanceSyncService.parseInvoiceDate(rawDate);
    final items = (invoiceData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

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
                        isArabic ? 'فاتورة مبيعات' : 'Sales Invoice',
                        style: pw.TextStyle(font: boldFont, fontSize: 22, color: PdfColor.fromHex('#4338CA')),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '#$invoiceNumber',
                        style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColor.fromHex('#6366F1')),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Mr.John ERP", style: pw.TextStyle(font: boldFont, fontSize: 16)),
                      pw.SizedBox(height: 2),
                      pw.Text(dateFmt.format(parsedDate), style: pw.TextStyle(font: bodyFont, fontSize: 10, color: PdfColors.grey700)),
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
                      pw.Text('${isArabic ? "العميل: " : "Customer: "}$clientName', style: pw.TextStyle(font: boldFont, fontSize: 11)),
                      pw.SizedBox(height: 4),
                      pw.Text('${isArabic ? "طريقة الدفع: " : "Payment Method: "}$paymentMethod', style: pw.TextStyle(font: bodyFont, fontSize: 10)),
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
                headerStyle: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.white),
                cellStyle: pw.TextStyle(font: bodyFont, fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                headers: isArabic
                    ? ['المنتج', 'الكمية', 'سعر الوحدة', 'الإجمالي']
                    : ['Product', 'Qty', 'Unit Price', 'Total'],
                data: items.map((item) {
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
                alignment: isArabic ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
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
                      _buildSummaryRow(isArabic ? 'المجموع الفرعي' : 'Subtotal', subtotal, bodyFont),
                      if (discount > 0)
                        _buildSummaryRow(isArabic ? 'الخصم' : 'Discount', -discount, bodyFont),
                      pw.Divider(color: PdfColors.grey300),
                      _buildSummaryRow(isArabic ? 'الإجمالي النهائي' : 'Total Amount', totalAmount, boldFont, isPrimary: true),
                      _buildSummaryRow(isArabic ? 'المبلغ المدفوع' : 'Paid Amount', paidAmount, bodyFont),
                      _buildSummaryRow(isArabic ? 'المتبقي' : 'Remaining', remainingAmount, boldFont, colorHex: '#DC2626'),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  isArabic ? 'شكراً لتعاملكم معنا!' : 'Thank you for your business!',
                  style: pw.TextStyle(font: headerFont, fontSize: 10, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(String label, double amount, pw.Font font, {bool isPrimary = false, String? colorHex}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: isPrimary ? 10 : 9)),
          pw.Text(
            '\$${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              font: font,
              fontSize: isPrimary ? 11 : 9,
              color: colorHex != null ? PdfColor.fromHex(colorHex) : (isPrimary ? PdfColor.fromHex('#4338CA') : PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRecordType(String type, bool isArabic) {
    if (isArabic) {
      switch (type) {
        case 'opening':
          return 'رصيد افتتاحي';
        case 'sales_invoice':
          return 'فاتورة مبيعات';
        case 'sales_return':
          return 'مرتجع مبيعات';
        case 'payment':
          return 'سداد رصيد';
        default:
          return 'حركة رصيد';
      }
    } else {
      switch (type) {
        case 'opening':
          return 'Opening Balance';
        case 'sales_invoice':
          return 'Sales Invoice';
        case 'sales_return':
          return 'Sales Return';
        case 'payment':
          return 'Payment';
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
}
