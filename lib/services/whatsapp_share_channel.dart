import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Flutter Method Channel interface for targeting WhatsApp with native Intent images & JID.
class WhatsappShareChannel {
  WhatsappShareChannel._();

  static const MethodChannel _channel = MethodChannel('app.store/whatsapp');

  /// Share single or multiple PNG image files directly to WhatsApp contact (phoneDigits) or default share sheet fallback.
  static Future<bool> shareImages({
    required String phoneDigits,
    required List<String> imagePaths,
    String? caption,
  }) async {
    if (imagePaths.isEmpty) return false;

    // Standardize phone digits
    String cleanDigits = phoneDigits.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.startsWith('01') && cleanDigits.length == 11) {
      cleanDigits = '2$cleanDigits';
    }

    if (kIsWeb || !Platform.isAndroid) {
      return _fallbackShareXFiles(imagePaths, caption);
    }

    try {
      final bool? result = await _channel.invokeMethod<bool>('shareImages', {
        'phone': cleanDigits,
        'paths': imagePaths,
        'text': caption ?? '',
      });
      return result ?? true;
    } on PlatformException catch (e) {
      debugPrint('WhatsappShareChannel failed on Android: ${e.message}. Using fallback share.');
      return _fallbackShareXFiles(imagePaths, caption);
    } catch (e) {
      debugPrint('Unexpected error in WhatsappShareChannel: $e. Using fallback share.');
      return _fallbackShareXFiles(imagePaths, caption);
    }
  }

  static Future<bool> _fallbackShareXFiles(List<String> imagePaths, String? caption) async {
    try {
      final xFiles = imagePaths.map((path) => XFile(path)).toList();
      final validCaption = (caption != null && caption.isNotEmpty) ? caption : null;
      await Share.shareXFiles(xFiles, text: validCaption);
      return true;
    } catch (e) {
      debugPrint('Fallback Share.shareXFiles failed: $e');
      return false;
    }
  }
}
