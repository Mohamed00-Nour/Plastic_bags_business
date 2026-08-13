import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';

/// Offstage Image Generator for paged Invoice Receipts using ScreenshotController.
class SalesInvoiceImageService {
  SalesInvoiceImageService._();

  /// Capture invoice into PNG image pages.
  /// If products.length > 12, splits items into pages of 12 items max per image.
  static Future<List<File>> generatePngPages({
    required Map<String, dynamic> invoiceData,
    Uint8List? pdfBytesFallback,
    double pixelRatio = 2.5,
    bool isSalesInvoice = true,
  }) async {
    final List<File> imageFiles = [];
    final items =
        (invoiceData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final invoiceNumber = invoiceData['invoiceNumber']?.toString() ?? 'INV-000';
    final tempDir = await getTemporaryDirectory();
    final sanitizeNumber = invoiceNumber.replaceAll(RegExp(r'[^\w-]'), '_');

    // Split items into chunks of max 12 items per receipt page
    const int chunkSize = 12;
    final List<List<Map<String, dynamic>>> itemPages = [];

    if (items.isEmpty) {
      itemPages.add([]);
    } else {
      for (int i = 0; i < items.length; i += chunkSize) {
        itemPages.add(
          items.sublist(
            i,
            (i + chunkSize > items.length) ? items.length : i + chunkSize,
          ),
        );
      }
    }

    final totalPages = itemPages.length;

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final pageItems = itemPages[pageIndex];
      final screenshotController = ScreenshotController();

      final widgetToCapture = MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: InvoiceReceiptCard(
            invoiceData: invoiceData,
            pageItems: pageItems,
            currentPage: pageIndex + 1,
            totalPages: totalPages,
            isSalesInvoice: isSalesInvoice,
          ),
        ),
      );

      try {
        final Uint8List imageBytes = await screenshotController
            .captureFromWidget(
              widgetToCapture,
              pixelRatio: pixelRatio,
              delay: const Duration(milliseconds: 20),
            );

        final pageSuffix = totalPages > 1 ? '_page_${pageIndex + 1}' : '';
        final file = File(
          '${tempDir.path}/Invoice_$sanitizeNumber$pageSuffix.png',
        );
        await file.writeAsBytes(imageBytes);
        imageFiles.add(file);
      } catch (e) {
        debugPrint(
          'Error rendering offstage invoice receipt page ${pageIndex + 1}: $e',
        );
      }
    }

    // Fallback: If screenshot capture failed and pdfBytes exist, rasterize PDF page
    if (imageFiles.isEmpty && pdfBytesFallback != null) {
      try {
        final stream = Printing.raster(pdfBytesFallback, pages: [0], dpi: 200);
        await for (final page in stream) {
          final pngBytes = await page.toPng();
          final file = File('${tempDir.path}/Invoice_$sanitizeNumber.png');
          await file.writeAsBytes(pngBytes);
          imageFiles.add(file);
          break;
        }
      } catch (e) {
        debugPrint('Fallback rasterization failed: $e');
      }
    }

    return imageFiles;
  }
}

/// Styled Receipt UI Widget used for offstage image rendering
class InvoiceReceiptCard extends StatelessWidget {
  final Map<String, dynamic> invoiceData;
  final List<Map<String, dynamic>> pageItems;
  final int currentPage;
  final int totalPages;
  final bool isSalesInvoice;

  const InvoiceReceiptCard({
    super.key,
    required this.invoiceData,
    required this.pageItems,
    required this.currentPage,
    required this.totalPages,
    required this.isSalesInvoice,
  });

  @override
  Widget build(BuildContext context) {
    final invoiceNumber = invoiceData['invoiceNumber']?.toString() ?? 'INV-000';
    final partyName =
        invoiceData['clientName']?.toString() ??
        invoiceData['supplierName']?.toString() ??
        'عميل نقدي';

    final totalAmount = (invoiceData['totalAmount'] ?? 0.0).toDouble();
    final paidAmount = (invoiceData['paidAmount'] ?? 0.0).toDouble();
    final remainingAmount =
        (invoiceData['remainingAmount'] ?? (totalAmount - paidAmount))
            .toDouble();
    final prevBalance =
        (invoiceData['previousBalance'] ?? invoiceData['prevBalance'] ?? 0.0)
            .toDouble();
    final totalDueBalance =
        (invoiceData['clientBalance'] ??
                invoiceData['currentBalance'] ??
                (prevBalance + remainingAmount))
            .toDouble();

    final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());

    return Container(
      width: 500,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSalesInvoice ? 'فاتورة مبيعات' : 'فاتورة شراء',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF38BDF8),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$invoiceNumber',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF475569)),
          const SizedBox(height: 8),

          // Party & Date Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${isSalesInvoice ? "العميل" : "المورد"}: $partyName',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                'التاريخ: $dateStr',
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          if (totalPages > 1) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'صفحة $currentPage من $totalPages',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF38BDF8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Items Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'الصنف',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'الكمية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'السعر',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'الإجمالي',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Items List
          ...pageItems.map((item) {
            final name = item['productName'] ?? item['name'] ?? 'منتج';
            final qty = item['quantity'] ?? 1;
            final price = (item['price'] ?? 0.0).toDouble();
            final itemTotal = price * qty;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF334155), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'x$qty',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${price.toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${itemTotal.toStringAsFixed(2)}',
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Show Summary Footer on the last page
          if (currentPage == totalPages) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF475569)),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'إجمالي الفاتورة:',
              '\$${totalAmount.toStringAsFixed(2)}',
              isBold: true,
            ),
            _buildSummaryRow(
              'المدفوع:',
              '\$${paidAmount.toStringAsFixed(2)}',
              color: const Color(0xFF4ADE80),
            ),
            _buildSummaryRow(
              'المتبقي من الفاتورة:',
              '\$${remainingAmount.toStringAsFixed(2)}',
              color: const Color(0xFFF87171),
            ),
            if (prevBalance > 0)
              _buildSummaryRow(
                'الرصيد السابق:',
                '\$${prevBalance.toStringAsFixed(2)}',
                color: const Color(0xFFFBBF24),
              ),
            _buildSummaryRow(
              isSalesInvoice
                  ? 'المتبقي عليكم (الرصيد الكلي):'
                  : 'الرصيد الحالي للمورد:',
              '\$${totalDueBalance.toStringAsFixed(2)}',
              isBold: true,
              color: const Color(0xFF38BDF8),
            ),
          ],

          const SizedBox(height: 18),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 8),

          // Easy App Signature
          const Column(
            children: [
              Text(
                'برمجة شركة easy app',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '01126697513',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.white,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.bold,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
