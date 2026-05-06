import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';

/// Sends FCM push notifications via the FCM HTTP v1 API using a Service Account.
/// The service account JSON is loaded from assets at runtime.
class FcmService {
  static const _serviceAccountAsset = 'assets/plastic-service-account.json';
  static const _projectId = 'john-441b1';
  static const _fcmScope = 'https://www.googleapis.com/auth/firebase.messaging';

  /// Sends an FCM notification to the [topic] with [title] and [body].
  static Future<void> sendToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    print('[FcmService] Loading service account credentials from assets...');
    final credentials = await _loadCredentials();
    print('[FcmService] Credentials loaded. client_email=${credentials.email}');

    print('[FcmService] Obtaining OAuth2 access token...');
    final authClient = await clientViaServiceAccount(credentials, [_fcmScope]);
    print('[FcmService] Access token obtained successfully.');

    try {
      final payload = {
        'message': {
          'topic': topic,
          'notification': {
            'title': title,
            'body': body,
          },
          if (data != null) 'data': data,
          'android': {
            'priority': 'high',
            'notification': {
              'sound': 'default',
              'channel_id': 'announcements',
            },
          },
          'apns': {
            'payload': {
              'aps': {
                'sound': 'default',
                'badge': 1,
              },
            },
          },
        },
      };

      final url =
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';
      print('[FcmService] Sending POST to $url');
      print('[FcmService] Payload: ${jsonEncode(payload)}');

      final response = await authClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('[FcmService] Response status: ${response.statusCode}');
      print('[FcmService] Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'FCM error ${response.statusCode}: ${response.body}',
        );
      }
      print('[FcmService] Notification sent successfully to topic "$topic".');
    } finally {
      authClient.close();
      print('[FcmService] Auth client closed.');
    }
  }

  static Future<ServiceAccountCredentials> _loadCredentials() async {
    print('[FcmService] Reading asset: $_serviceAccountAsset');
    final jsonStr = await rootBundle.loadString(_serviceAccountAsset);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    print('[FcmService] Asset parsed. project_id=${json['project_id']}');
    return ServiceAccountCredentials.fromJson(json);
  }
}
