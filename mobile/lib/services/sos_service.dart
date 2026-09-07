import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_contact.dart';
import 'emergency_contact_storage.dart';
import 'sos_notification_service.dart';

class SosService {
  SosService({
    EmergencyContactStorage? storage,
    SosNotificationService? notificationService,
  })  : _storage = storage ?? EmergencyContactStorage(),
        _notifications = notificationService ?? SosNotificationService();

  final EmergencyContactStorage _storage;
  final SosNotificationService _notifications;

  Future<void> notifyCaregivers({required String message}) async {
    try {
      await _notifications.sendSosAlert(message: message);
    } catch (e) {
      if (kDebugMode) debugPrint('SOS notify error: $e');
    }
  }

  Future<List<EmergencyContact>> getCallList() => _storage.getSosContacts();

  Future<SosCallResult> startCallChain() async {
    final contacts = await getCallList();
    if (contacts.isEmpty) {
      return const SosCallResult(success: false, message: 'Belum ada kontak SOS');
    }

    await notifyCaregivers(
      message: 'Pasien memicu SOS. Sistem menghubungi kontak darurat.',
    );

    for (final contact in contacts) {
      final ok = await _dial(contact.phone);
      if (ok) {
        return SosCallResult(
          success: true,
          message: 'Memanggil ${contact.name} (prioritas ${contact.priority})',
          contact: contact,
        );
      }
    }

    return const SosCallResult(
      success: false,
      message: 'Gagal membuka aplikasi telepon',
    );
  }

  Future<bool> dialContact(EmergencyContact contact) => _dial(contact.phone);

  Future<bool> _dial(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri);
    }
    return false;
  }
}

class SosCallResult {
  const SosCallResult({
    required this.success,
    required this.message,
    this.contact,
  });

  final bool success;
  final String message;
  final EmergencyContact? contact;
}
