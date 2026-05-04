import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/product_model_new.dart';

class PdfService {
  static final _currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _dateFmt = DateFormat('MMM dd, yyyy');

  static Future<void> generateSalesReport({
    required List<OrderModel> orders,
    required List<TransactionModel> transactions,
    required DateTime startDate,
    required DateTime endDate,
    required double totalSales,
    required double totalCharges,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader('Sales Report',
            '${_dateFmt.format(startDate)} - ${_dateFmt.format(endDate)}'),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Total Orders', '${orders.length}'),
                _summaryItem('Total Sales', _currFmt.format(totalSales)),
                _summaryItem('Balance Charges', _currFmt.format(totalCharges)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Orders Table
          pw.Text('Orders',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.all(6),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
            },
            headers: ['Order ID', 'Shop', 'Total', 'Status', 'Date'],
            data: orders.map((o) {
              return [
                '#${o.id.substring(0, 8)}',
                o.shopName,
                _currFmt.format(o.totalPrice),
                o.status.label,
                _dateFmt.format(o.createdAt),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 20),

          // Transactions Table
          pw.Text('Transactions',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.all(6),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerLeft,
            },
            headers: ['Date', 'Type', 'Party', 'Amount', 'Description'],
            data: transactions.map((t) {
              return [
                _dateFmt.format(t.createdAt),
                t.type.label,
                t.shopName ?? t.supplierName ?? '-',
                _currFmt.format(t.amount),
                t.description ?? '-',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Sales_Report_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}',
    );
  }

  static Future<void> generateInventoryReport() async {
    // Fetch products directly
    final snapshot =
        await FirebaseFirestore.instance.collection('products').get();
    final products =
        snapshot.docs.map((d) => ProductModel.fromFirestore(d)).toList();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) =>
            _buildHeader('Inventory Report', _dateFmt.format(DateTime.now())),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Total Products', '${products.length}'),
                _summaryItem('Low Stock Items',
                    '${products.where((p) => p.isLowStock).length}'),
                _summaryItem(
                    'Total Value',
                    _currFmt.format(products.fold<double>(
                        0, (s, p) => s + (p.price * p.stockQuantity)))),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Products Table
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.all(6),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.center,
            },
            headers: [
              'Product',
              'Size',
              'Price',
              'Cost',
              'Stock',
              'Status'
            ],
            data: products.map((p) {
              return [
                p.name,
                p.size,
                _currFmt.format(p.price),
                _currFmt.format(p.costPrice),
                '${p.stockQuantity}',
                p.isLowStock ? 'LOW' : 'OK',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Inventory_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }

  static Future<void> generateShopStatement({
    required String shopId,
    required String shopName,
    required List<TransactionModel> transactions,
    required double currentBalance,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) =>
            _buildHeader('Shop Statement - $shopName', _dateFmt.format(DateTime.now())),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Transactions', '${transactions.length}'),
                _summaryItem(
                    'Current Balance', _currFmt.format(currentBalance)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.all(6),
            headers: ['Date', 'Type', 'Amount', 'Balance', 'Description'],
            data: transactions.map((t) {
              return [
                _dateFmt.format(t.createdAt),
                t.type.label,
                _currFmt.format(t.amount),
                _currFmt.format(t.balanceAfter),
                t.description ?? '-',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Statement_${shopName}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }

  static Future<void> generateSupplierInvoice({
    required String supplierId,
    required String supplierName,
    required List<TransactionModel> transactions,
    required double currentBalance,
  }) async {
    final pdf = pw.Document();

    final totalPayments = transactions
        .where((t) => t.type == TransactionType.supplierPayment)
        .fold<double>(0, (s, t) => s + t.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(
            'Supplier Invoice - $supplierName',
            _dateFmt.format(DateTime.now())),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Transactions', '${transactions.length}'),
                _summaryItem('Total Payments', _currFmt.format(totalPayments)),
                _summaryItem(
                    'Current Balance', _currFmt.format(currentBalance)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.all(6),
            headers: ['Date', 'Type', 'Amount', 'Balance', 'Description'],
            data: transactions.map((t) {
              return [
                _dateFmt.format(t.createdAt),
                t.type.label,
                _currFmt.format(t.amount),
                _currFmt.format(t.balanceAfter),
                t.description ?? '-',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Supplier_Invoice_${supplierName}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }

  // ── Build-only methods (return bytes; callers show PdfPreview) ──────────

  static Future<Uint8List> buildSalesReportBytes({
    required List<OrderModel> orders,
    required List<TransactionModel> transactions,
    required DateTime startDate,
    required DateTime endDate,
    required double totalSales,
    required double totalCharges,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader('Sales Report',
            '${_dateFmt.format(startDate)} - ${_dateFmt.format(endDate)}'),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Total Orders', '${orders.length}'),
                _summaryItem('Total Sales', _currFmt.format(totalSales)),
                _summaryItem('Balance Charges', _currFmt.format(totalCharges)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Orders',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.all(6),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
            },
            headers: ['Order ID', 'Shop', 'Total', 'Status', 'Date'],
            data: orders.map((o) => [
              '#${o.id.substring(0, 8)}',
              o.shopName,
              _currFmt.format(o.totalPrice),
              o.status.label,
              _dateFmt.format(o.createdAt),
            ]).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Transactions',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.all(6),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerLeft,
            },
            headers: ['Date', 'Type', 'Party', 'Amount', 'Description'],
            data: transactions.map((t) => [
              _dateFmt.format(t.createdAt),
              t.type.label,
              t.shopName ?? t.supplierName ?? '-',
              _currFmt.format(t.amount),
              t.description ?? '-',
            ]).toList(),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> buildInventoryReportBytes() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('products').get();
    final products =
        snapshot.docs.map((d) => ProductModel.fromFirestore(d)).toList();
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) =>
            _buildHeader('Inventory Report', _dateFmt.format(DateTime.now())),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Total Products', '${products.length}'),
                _summaryItem('Low Stock Items',
                    '${products.where((p) => p.isLowStock).length}'),
                _summaryItem(
                    'Total Value',
                    _currFmt.format(products.fold<double>(
                        0, (s, p) => s + (p.price * p.stockQuantity)))),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.all(6),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.center,
            },
            headers: ['Product', 'Size', 'Price', 'Cost', 'Stock', 'Status'],
            data: products.map((p) => [
              p.name,
              p.size,
              _currFmt.format(p.price),
              _currFmt.format(p.costPrice),
              '${p.stockQuantity}',
              p.isLowStock ? 'LOW' : 'OK',
            ]).toList(),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> buildShopStatementBytes({
    required String shopId,
    required String shopName,
    required List<TransactionModel> transactions,
    required double currentBalance,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(
            'Shop Statement - $shopName', _dateFmt.format(DateTime.now())),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Transactions', '${transactions.length}'),
                _summaryItem(
                    'Current Balance', _currFmt.format(currentBalance)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.all(6),
            headers: ['Date', 'Type', 'Amount', 'Balance', 'Description'],
            data: transactions.map((t) => [
              _dateFmt.format(t.createdAt),
              t.type.label,
              _currFmt.format(t.amount),
              _currFmt.format(t.balanceAfter),
              t.description ?? '-',
            ]).toList(),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> buildSupplierInvoiceBytes({
    required String supplierId,
    required String supplierName,
    required List<TransactionModel> transactions,
    required List<ProductModel> products,
    required double currentBalance,
  }) async {
    final totalPayments = transactions
        .where((t) => t.type == TransactionType.supplierPayment)
        .fold<double>(0, (s, t) => s + t.amount);
    final totalProductValue = products.fold<double>(
        0, (s, p) => s + (p.costPrice * p.stockQuantity));

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(
            'Supplier Invoice - $supplierName',
            _dateFmt.format(DateTime.now())),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Products', '${products.length}'),
                _summaryItem('Stock Value', _currFmt.format(totalProductValue)),
                _summaryItem('Total Payments', _currFmt.format(totalPayments)),
                _summaryItem('Current Balance', _currFmt.format(currentBalance)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Products from this supplier
          pw.Text('Products Supplied',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (products.isEmpty)
            pw.Text('No products linked to this supplier.',
                style: const pw.TextStyle(color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellPadding: const pw.EdgeInsets.all(6),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              headers: ['Product', 'Size', 'Cost Price', 'Stock', 'Total Value'],
              data: products.map((p) => [
                p.name,
                p.size,
                _currFmt.format(p.costPrice),
                '${p.stockQuantity}',
                _currFmt.format(p.costPrice * p.stockQuantity),
              ]).toList(),
            ),
          pw.SizedBox(height: 20),

          // Payment transactions
          pw.Text('Payment History',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (transactions.isEmpty)
            pw.Text('No payment transactions recorded.',
                style: const pw.TextStyle(color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellPadding: const pw.EdgeInsets.all(6),
              headers: ['Date', 'Type', 'Amount', 'Balance', 'Description'],
              data: transactions.map((t) => [
                _dateFmt.format(t.createdAt),
                t.type.label,
                _currFmt.format(t.amount),
                _currFmt.format(t.balanceAfter),
                t.description ?? '-',
              ]).toList(),
            ),
        ],
      ),
    );
    return pdf.save();
  }

  // --- Helpers ---

  static pw.Widget _buildHeader(String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(title,
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Plastic Bags Business',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(subtitle,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        pw.Divider(),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated on ${_dateFmt.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(value,
            style:
                pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }
}
