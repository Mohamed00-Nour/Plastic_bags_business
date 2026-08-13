import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import 'sales_invoice_image_service.dart';
import 'whatsapp_share_channel.dart';

/// Share Service & UI Orchestrator for direct WhatsApp messaging and PNG image targeted sharing.
class WhatsappInvoiceShareService {
  WhatsappInvoiceShareService._();

  /// Clean non-digits from raw phone string (e.g. "+20 112 669 7513" -> "201126697513")
  static String cleanPhoneDigits(String rawPhone) {
    String clean = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('01') && clean.length == 11) {
      clean = '2$clean';
    }
    return clean;
  }

  /// Query Firestore to lookup Client or Supplier phone number if not present in invoice map.
  static Future<String> fetchClientPhone(Map<String, dynamic> invoiceData) async {
    String phone = invoiceData['clientPhone']?.toString() ??
        invoiceData['supplierPhone']?.toString() ??
        invoiceData['phone']?.toString() ??
        '';

    if (phone.trim().isNotEmpty) return cleanPhoneDigits(phone);

    final firestore = FirebaseFirestore.instance;

    final clientId = invoiceData['clientId']?.toString();
    final clientName = invoiceData['clientName']?.toString();

    if (clientId != null && clientId.isNotEmpty) {
      try {
        final doc = await firestore.collection('clients').doc(clientId).get();
        if (doc.exists && doc.data()?['phone'] != null) {
          return cleanPhoneDigits(doc.data()!['phone'].toString());
        }
      } catch (_) {}
    }

    if (clientName != null && clientName.isNotEmpty) {
      try {
        final query = await firestore
            .collection('clients')
            .where('name', isEqualTo: clientName)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final p = query.docs.first.data()['phone']?.toString() ?? '';
          if (p.isNotEmpty) return cleanPhoneDigits(p);
        }
      } catch (_) {}
    }

    final supplierId = invoiceData['supplierId']?.toString();
    final supplierName = invoiceData['supplierName']?.toString();

    if (supplierId != null && supplierId.isNotEmpty) {
      try {
        final doc = await firestore.collection('suppliers').doc(supplierId).get();
        if (doc.exists && doc.data()?['phone'] != null) {
          return cleanPhoneDigits(doc.data()!['phone'].toString());
        }
      } catch (_) {}
    }

    if (supplierName != null && supplierName.isNotEmpty) {
      try {
        final query = await firestore
            .collection('suppliers')
            .where('name', isEqualTo: supplierName)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final p = query.docs.first.data()['phone']?.toString() ?? '';
          if (p.isNotEmpty) return cleanPhoneDigits(p);
        }
      } catch (_) {}
    }

    return '';
  }

  /// Format Arabic invoice details into a clean text block
  static String buildInvoiceMessage(Map<String, dynamic> invoiceData, {bool isSalesInvoice = true}) {
    final invoiceNumber = invoiceData['invoiceNumber']?.toString() ?? 'INV-000';
    final partyName = invoiceData['clientName']?.toString() ??
        invoiceData['supplierName']?.toString() ??
        'عميل نقدي';

    final rawDate = invoiceData['date'] ?? invoiceData['createdAt'];
    DateTime parsedDate = DateTime.now();
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(parsedDate);
    final items = (invoiceData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final subtotal = (invoiceData['subtotal'] ?? 0.0).toDouble();
    final discount = (invoiceData['discount'] ?? 0.0).toDouble();
    final totalAmount = (invoiceData['totalAmount'] ?? (subtotal - discount)).toDouble();
    final paidAmount = (invoiceData['paidAmount'] ?? 0.0).toDouble();
    final remainingAmount = (invoiceData['remainingAmount'] ?? (totalAmount - paidAmount)).toDouble();

    final prevBalance = (invoiceData['previousBalance'] ?? invoiceData['prevBalance'] ?? 0.0).toDouble();
    final totalDueBalance = (invoiceData['clientBalance'] ?? invoiceData['currentBalance'] ?? (prevBalance + remainingAmount)).toDouble();

    final itemsSummary = items.map((item) {
      final name = item['productName'] ?? item['name'] ?? 'منتج';
      final qty = item['quantity'] ?? 1;
      final price = (item['price'] ?? 0.0).toDouble();
      return "• $name (x$qty) - \$${price.toStringAsFixed(2)}";
    }).join('\n');

    final invoiceHeader = isSalesInvoice
        ? "🧾 *فاتورة رقم #$invoiceNumber*"
        : "🧾 *فاتورة مشتريات رقم #$invoiceNumber*";

    final partyHeader = isSalesInvoice
        ? "👤 *العميل:* $partyName"
        : "👤 *المورد:* $partyName";

    final balanceFooter = isSalesInvoice
        ? "💰 *المتبقي عليكم:* \$${totalDueBalance.toStringAsFixed(2)}"
        : "💰 *الرصيد الحالي للمورد:* \$${totalDueBalance.toStringAsFixed(2)}";

    return "$invoiceHeader\n"
        "$partyHeader\n"
        "📅 *التاريخ:* $dateStr\n"
        "----------------------------------\n"
        "📦 *تفاصيل الأصناف:*\n"
        "${itemsSummary.isEmpty ? '• لا يوجد أصناف' : itemsSummary}\n"
        "----------------------------------\n"
        "${prevBalance > 0 ? '⏮️ *الرصيد السابق:* \$${prevBalance.toStringAsFixed(2)}\n' : ''}"
        "💵 *إجمالي الفاتورة:* \$${totalAmount.toStringAsFixed(2)}\n"
        "${discount > 0 ? '🏷️ *الخصم:* \$${discount.toStringAsFixed(2)}\n' : ''}"
        "💳 *المدفوع:* \$${paidAmount.toStringAsFixed(2)}\n"
        "📌 *المتبقي من الفاتورة:* \$${remainingAmount.toStringAsFixed(2)}\n"
        "----------------------------------\n"
        "$balanceFooter\n\n"
        "شكراً لتعاملكم معنا! ✨\n\n"
        "برمجة شركة easy app\n"
        "01126697513";
  }

  /// Launch WhatsApp chat using URL scheme fallback order:
  /// 1. https://wa.me/$phone?text=$encoded
  /// 2. whatsapp://send?phone=$phone&text=$encoded
  static Future<bool> openWhatsappChat({
    String? phoneDigits,
    required String message,
  }) async {
    final phone = cleanPhoneDigits(phoneDigits ?? '');
    final encoded = Uri.encodeComponent(message);

    final List<Uri> urisToTry = [];
    if (phone.isNotEmpty) {
      urisToTry.add(Uri.parse("https://wa.me/$phone?text=$encoded"));
      urisToTry.add(Uri.parse("whatsapp://send?phone=$phone&text=$encoded"));
      urisToTry.add(Uri.parse("https://api.whatsapp.com/send?phone=$phone&text=$encoded"));
    } else {
      urisToTry.add(Uri.parse("https://wa.me/?text=$encoded"));
      urisToTry.add(Uri.parse("whatsapp://send?text=$encoded"));
      urisToTry.add(Uri.parse("https://api.whatsapp.com/send?text=$encoded"));
    }

    for (final uri in urisToTry) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) return true;
        }
      } catch (_) {}
    }

    try {
      return await launchUrl(urisToTry.first, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching WhatsApp URL: $e');
      return false;
    }
  }

  /// Share Invoice as Text Message to WhatsApp
  static Future<void> shareAsTextMessage({
    required Map<String, dynamic> invoiceData,
    bool isSalesInvoice = true,
  }) async {
    final phone = await fetchClientPhone(invoiceData);
    final message = buildInvoiceMessage(invoiceData, isSalesInvoice: isSalesInvoice);
    await openWhatsappChat(phoneDigits: phone, message: message);
  }

  /// Share Invoice as High-Resolution PNG Image(s) directly to WhatsApp
  static Future<void> shareAsImage({
    required BuildContext context,
    required Map<String, dynamic> invoiceData,
    Uint8List? pdfBytes,
    bool isSalesInvoice = true,
  }) async {
    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => const Center(
        child: Card(
          color: Color(0xFF1E293B),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF25D366)),
                SizedBox(width: 16),
                Text(
                  'جاري تجهيز صورة الفاتورة...',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final phone = await fetchClientPhone(invoiceData);

      // Generate Offstage PNG Receipt Files
      final imageFiles = await SalesInvoiceImageService.generatePngPages(
        invoiceData: invoiceData,
        pdfBytesFallback: pdfBytes,
        pixelRatio: 2.5,
        isSalesInvoice: isSalesInvoice,
      );

      // Dismiss Loading Dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (imageFiles.isEmpty) {
        return;
      }

      // Invoke Android Method Channel / Native Intent (only sending images, no text block)
      final imagePaths = imageFiles.map((f) => f.path).toList();
      await WhatsappShareChannel.shareImages(
        phoneDigits: phone,
        imagePaths: imagePaths,
        caption: '',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء إنشاء الصورة: $e')),
        );
      }
    }
  }

  /// Display Arabic Share Options Modal Bottom Sheet
  static Future<void> showShareOptions({
    required BuildContext context,
    required Map<String, dynamic> invoiceData,
    Uint8List? pdfBytes,
    bool isSalesInvoice = true,
  }) async {
    final rawPhone = await fetchClientPhone(invoiceData);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'خيارات المشاركة عبر واتساب',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (rawPhone.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone_android_rounded, color: Color(0xFF25D366), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'رقم الواتساب: $rawPhone',
                          style: const TextStyle(
                            color: Color(0xFF25D366),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'لم يتم تحديد رقم هاتف للعميل (سيتم فتح اختيار المستلم في واتساب)',
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),

                // Option 1: Text Message
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF128C7E),
                    child: Icon(Icons.chat_rounded, color: Colors.white),
                  ),
                  title: const Text('رسالة نصية (Text Message)'),
                  subtitle: Text(
                    rawPhone.isNotEmpty
                        ? 'إرسال ملخص الفاتورة كنص إلى $rawPhone'
                        : 'فتح واتساب مع نص ملخص الفاتورة واختيار المستلم',
                  ),
                  onTap: () async {
                    Navigator.of(bContext).pop();
                    await shareAsTextMessage(
                      invoiceData: invoiceData,
                      isSalesInvoice: isSalesInvoice,
                    );
                  },
                ),
                const Divider(),

                // Option 2: Invoice Image
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF25D366),
                    child: Icon(Icons.image_rounded, color: Colors.white),
                  ),
                  title: const Text('صورة الفاتورة (Invoice Image)'),
                  subtitle: Text(
                    rawPhone.isNotEmpty
                        ? 'إنشاء صورة عالية الجودة ومشاركتها مع $rawPhone'
                        : 'إنشاء صورة عالية الجودة للفاتورة ومشاركتها',
                  ),
                  onTap: () async {
                    Navigator.of(bContext).pop();
                    await shareAsImage(
                      context: context,
                      invoiceData: invoiceData,
                      pdfBytes: pdfBytes,
                      isSalesInvoice: isSalesInvoice,
                    );
                  },
                ),
                const Divider(),

                // Option 3: PDF Document
                if (pdfBytes != null)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                    ),
                    title: const Text('ملف الفاتورة PDF (PDF Document)'),
                    subtitle: const Text('مشاركة ملف المستند PDF عبر واتساب أو التطبيقات'),
                    onTap: () async {
                      Navigator.of(bContext).pop();
                      final invoiceNumber = invoiceData['invoiceNumber']?.toString() ?? 'INV-000';
                      try {
                        Directory? downloadsDir;
                        try {
                          downloadsDir = await getDownloadsDirectory();
                        } catch (_) {}
                        downloadsDir ??= await getTemporaryDirectory();
                        final pdfFile = File('${downloadsDir.path}/Invoice_$invoiceNumber.pdf');
                        await pdfFile.writeAsBytes(pdfBytes);
                      } catch (_) {}

                      await Printing.sharePdf(
                        bytes: pdfBytes,
                        filename: 'Invoice_$invoiceNumber.pdf',
                        subject: buildInvoiceMessage(invoiceData, isSalesInvoice: isSalesInvoice),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
