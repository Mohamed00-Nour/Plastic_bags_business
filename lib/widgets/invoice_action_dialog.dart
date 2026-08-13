import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../core/theme/app_theme.dart';
import '../features/reports/presentation/widgets/report_preview_dialog.dart';
import '../services/whatsapp_invoice_share_service.dart';

class InvoiceActionDialog extends StatelessWidget {
  final Map<String, dynamic> invoiceData;
  final Uint8List pdfBytes;
  final String locale;
  final bool isSalesInvoice;

  const InvoiceActionDialog({
    super.key,
    required this.invoiceData,
    required this.pdfBytes,
    this.locale = 'ar',
    this.isSalesInvoice = true,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> invoiceData,
    required Uint8List pdfBytes,
    String locale = 'ar',
    bool isSalesInvoice = true,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => InvoiceActionDialog(
        invoiceData: invoiceData,
        pdfBytes: pdfBytes,
        locale: locale,
        isSalesInvoice: isSalesInvoice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = locale == 'ar';
    final invoiceNumber = invoiceData['invoiceNumber']?.toString() ?? 'INV-000';
    final clientOrSupplierName = invoiceData['clientName']?.toString() ??
        invoiceData['supplierName']?.toString() ??
        (isArabic ? 'عميل نقدي' : 'Cash Client');
    final totalAmount = (invoiceData['totalAmount'] ?? 0.0).toDouble();
    final remainingAmount = (invoiceData['remainingAmount'] ?? 0.0).toDouble();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleText = isSalesInvoice
        ? (isArabic ? 'تم حفظ فاتورة المبيعات' : 'Sales Invoice Saved')
        : (isArabic ? 'تم حفظ فاتورة الشراء' : 'Buying Invoice Saved');

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon Header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.successColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                titleText,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle Banner Info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.inputFillDark : AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#$invoiceNumber',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          clientOrSupplierName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.successColor,
                          ),
                        ),
                        if (remainingAmount > 0)
                          Text(
                            isArabic
                                ? 'المتبقي: \$${remainingAmount.toStringAsFixed(2)}'
                                : 'Remaining: \$${remainingAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.dangerColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4 Main Action Cards
              Column(
                children: [
                  // Action 1: Share to WhatsApp
                  _buildActionCard(
                    context: context,
                    isDark: isDark,
                    icon: Icons.chat_rounded,
                    iconColor: const Color(0xFF25D366), // WhatsApp Green
                    title: isArabic ? 'مشاركة عبر واتساب' : 'Share to WhatsApp',
                    subtitle: isArabic
                        ? 'إرسال نص الفاتورة أو ملخص للعميل'
                        : 'Send text summary or file to client',
                    onTap: () => _shareToWhatsApp(context, isArabic),
                  ),
                  const SizedBox(height: 10),

                  // Action 2: Print Invoice
                  _buildActionCard(
                    context: context,
                    isDark: isDark,
                    icon: Icons.print_rounded,
                    iconColor: AppTheme.primaryColor,
                    title: isArabic ? 'طباعة الفاتورة' : 'Print Invoice',
                    subtitle: isArabic
                        ? 'طباعة ورقية مباشرة عبر الطابعة'
                        : 'Print directly via local printer',
                    onTap: () => _printInvoice(context),
                  ),
                  const SizedBox(height: 10),

                  // Action 3: Display / Preview Invoice
                  _buildActionCard(
                    context: context,
                    isDark: isDark,
                    icon: Icons.visibility_rounded,
                    iconColor: AppTheme.accentColor,
                    title: isArabic ? 'عرض الفاتورة' : 'Display Invoice',
                    subtitle: isArabic
                        ? 'معاينة ملف PDF بالتفصيل'
                        : 'View full PDF preview on screen',
                    onTap: () => _displayInvoice(context),
                  ),
                  const SizedBox(height: 10),

                  // Action 4: Save on Device
                  _buildActionCard(
                    context: context,
                    isDark: isDark,
                    icon: Icons.download_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: isArabic ? 'حفظ على الجهاز' : 'Save on Device',
                    subtitle: isArabic
                        ? 'تنزيل وحفظ ملف PDF على جهازك'
                        : 'Save PDF file to local storage',
                    onTap: () => _saveToDevice(context, isArabic),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Close / Done Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isArabic ? 'إغلاق' : 'Close',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.inputFillDark.withValues(alpha: 0.6)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? AppTheme.borderDark
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark
                          ? AppTheme.textPrimaryDark
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppTheme.textSecondaryDark : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _shareToWhatsApp(BuildContext context, bool isArabic) async {
    await WhatsappInvoiceShareService.showShareOptions(
      context: context,
      invoiceData: invoiceData,
      pdfBytes: pdfBytes,
      isSalesInvoice: isSalesInvoice,
    );
  }

  void _printInvoice(BuildContext context) async {
    await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
  }

  void _displayInvoice(BuildContext context) {
    final invoiceNumber = invoiceData['invoiceNumber']?.toString() ?? 'INV-000';
    showDialog(
      context: context,
      builder: (ctx) => ReportPreviewDialog(
        title: '${isSalesInvoice ? "Invoice" : "Buying_Invoice"}_$invoiceNumber',
        buildPdf: (_) async => pdfBytes,
      ),
    );
  }

  void _saveToDevice(BuildContext context, bool isArabic) async {
    final invoiceNumber = invoiceData['invoiceNumber']?.toString() ?? 'INV-000';
    final fileName = 'Invoice_$invoiceNumber.pdf';

    try {
      Directory? outputDir;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        outputDir = await getDownloadsDirectory();
        outputDir ??= await getApplicationDocumentsDirectory();
      } else {
        outputDir = await getApplicationDocumentsDirectory();
      }

      final file = File('${outputDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تم حفظ الفاتورة بنجاح في: ${file.path}'
                  : 'Saved invoice successfully to: ${file.path}',
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Fallback using Printing.sharePdf / save dialog
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );
    }
  }
}
