import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'supplier_invoice_balance_sync_service.dart';

class SupplierStatementPdfService {
  SupplierStatementPdfService._();

  /// Generate Supplier Account Statement PDF (Bilingual support for AR/EN based on locale)
  static Future<Uint8List> generateSupplierStatementPdf({
    required Map<String, dynamic> supplierData,
    required List<SupplierBalanceRecord> records,
    String locale = 'ar',
  }) async {
    final pdf = pw.Document();
    final isArabic = locale == 'ar';
    final dateFmt = DateFormat('yyyy/MM/dd HH:mm');

    final bodyFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final direction = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final supplierName = supplierData['name'] ?? (isArabic ? 'مورد بدون اسم' : 'Unnamed Supplier');
    final supplierPhone = supplierData['phone'] ?? '';
    final supplierAddress = supplierData['address'] ?? '';
    final currentBalance = (supplierData['totalBalance'] ?? supplierData['balance'] ?? 0.0).toDouble();

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
                        isArabic ? 'كشف حساب مورد' : 'Supplier Account Statement',
                        style: pw.TextStyle(font: boldFont, fontSize: 20, color: PdfColor.fromHex('#0EA5E9')),
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

              // Supplier Info Section
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
                          '${isArabic ? "اسم المورد: " : "Supplier Name: "}$supplierName',
                          style: pw.TextStyle(font: boldFont, fontSize: 12),
                        ),
                        if (supplierPhone.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '${isArabic ? "الهاتف: " : "Phone: "}$supplierPhone',
                            style: pw.TextStyle(font: bodyFont, fontSize: 10),
                          ),
                        ],
                        if (supplierAddress.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '${isArabic ? "العنوان: " : "Address: "}$supplierAddress',
                            style: pw.TextStyle(font: bodyFont, fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: currentBalance > 0 ? PdfColor.fromHex('#FFFBEB') : PdfColor.fromHex('#ECFDF5'),
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(
                          color: currentBalance > 0 ? PdfColor.fromHex('#FCD34D') : PdfColor.fromHex('#6EE7B7'),
                        ),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            isArabic ? 'رصيد المورد المستحق' : 'Supplier Credit Balance',
                            style: pw.TextStyle(font: bodyFont, fontSize: 9, color: PdfColors.grey700),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '\$${currentBalance.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 16,
                              color: currentBalance > 0 ? PdfColor.fromHex('#D97706') : PdfColor.fromHex('#059669'),
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
                  color: PdfColor.fromHex('#0EA5E9'),
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

  /// Generate Buying Invoice Printable Receipt PDF
  static Future<Uint8List> generateBuyingInvoicePdf({
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

    final invoiceNumber = invoiceData['invoiceNumber'] ?? 'PUR-000';
    final supplierName = invoiceData['supplierName'] ?? (isArabic ? 'مورد نقدي' : 'Cash Supplier');
    final paymentMethod = invoiceData['paymentMethod'] ?? 'Cash';
    final rawDate = invoiceData['date'] ?? invoiceData['createdAt'];
    final parsedDate = SupplierInvoiceBalanceSyncService.parseInvoiceDate(rawDate);
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
                        isArabic ? 'فاتورة شراء / توريد' : 'Purchase / Buying Invoice',
                        style: pw.TextStyle(font: boldFont, fontSize: 22, color: PdfColor.fromHex('#0EA5E9')),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '#$invoiceNumber',
                        style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColor.fromHex('#0284C7')),
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
                      pw.Text('${isArabic ? "المورد: " : "Supplier: "}$supplierName', style: pw.TextStyle(font: boldFont, fontSize: 11)),
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
                  color: PdfColor.fromHex('#0EA5E9'),
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(6),
                    topRight: pw.Radius.circular(6),
                  ),
                ),
                headerStyle: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.white),
                cellStyle: pw.TextStyle(font: bodyFont, fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                headers: isArabic
                    ? ['المنتج المورد', 'الكمية', 'تكلفة الوحدة', 'الإجمالي']
                    : ['Product Supplied', 'Qty', 'Unit Cost', 'Total'],
                data: items.map((item) {
                  final name = item['productName'] ?? '';
                  final qty = item['quantity'] ?? 0;
                  final cost = (item['costPrice'] ?? item['price'] ?? 0.0).toDouble();
                  final total = (item['total'] ?? (qty * cost)).toDouble();
                  return [
                    name,
                    '$qty',
                    '\$${cost.toStringAsFixed(2)}',
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
                      _buildSummaryRow(isArabic ? 'المتبقي للمورد' : 'Remaining Due', remainingAmount, boldFont, colorHex: '#D97706'),
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
                  isArabic ? 'إيصال استلام وتوريد بضاعة معتمد' : 'Verified Goods Receipt & Purchase Voucher',
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
              color: colorHex != null ? PdfColor.fromHex(colorHex) : (isPrimary ? PdfColor.fromHex('#0EA5E9') : PdfColors.black),
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
        case 'buying_invoice':
          return 'فاتورة شراء';
        case 'purchase_return':
          return 'مرتجع مشتريات';
        case 'payment':
          return 'سداد للمورد';
        default:
          return 'حركة رصيد';
      }
    } else {
      switch (type) {
        case 'opening':
          return 'Opening Balance';
        case 'buying_invoice':
          return 'Buying Invoice';
        case 'purchase_return':
          return 'Purchase Return';
        case 'payment':
          return 'Supplier Payment';
        default:
          return 'Transaction';
      }
    }
  }

  /// Print or Share Supplier Statement PDF
  static Future<void> printOrShareSupplierStatement({
    required Map<String, dynamic> supplierData,
    required List<SupplierBalanceRecord> records,
    String locale = 'ar',
  }) async {
    final pdfBytes = await generateSupplierStatementPdf(
      supplierData: supplierData,
      records: records,
      locale: locale,
    );
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }

  /// Print or Share Buying Invoice PDF
  static Future<void> printOrShareBuyingInvoice({
    required Map<String, dynamic> invoiceData,
    String locale = 'ar',
  }) async {
    final pdfBytes = await generateBuyingInvoicePdf(
      invoiceData: invoiceData,
      locale: locale,
    );
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }
}
