import 'dart:io';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailService {
  static const MethodChannel _channel = MethodChannel('com.prabincode.luminaexpense/email');

  static Future<bool> sendEmail({
    required String recipient,
    required String subject,
    required String body,
    String? attachmentPath,
  }) async {
    // 1. On Android, use our native Intent with FileProvider for guaranteed recipient + attachments
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>('sendEmail', {
          'recipient': recipient,
          'subject': subject,
          'body': body,
          'attachmentPath': attachmentPath,
        });
        if (result == true) return true;
      } catch (e) {
        // Fall through to cross-platform fallbacks
      }
    }

    // 2. If attachment is present on other platforms, use shareXFiles
    if (attachmentPath != null && File(attachmentPath).existsSync()) {
      try {
        final xFile = XFile(attachmentPath);
        await Share.shareXFiles(
          [xFile],
          subject: subject,
          text: '$body\n\n(Send to: $recipient)',
        );
        return true;
      } catch (_) {}
    }

    // 3. RFC-compliant mailto URI fallback
    try {
      String encodeQuery(Map<String, String> params) {
        return params.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
      }

      final mailtoUri = Uri(
        scheme: 'mailto',
        path: recipient,
        query: encodeQuery({
          'subject': subject,
          'body': body,
        }),
      );

      final launched = await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {}

    // 4. Final fallback to system share
    await Share.share(
      '$body\n\n(Send to: $recipient)',
      subject: subject,
    );
    return true;
  }
}
