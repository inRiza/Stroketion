import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../models/sos_alert.dart';
import '../../../../services/sos_notification_service.dart';
import '../../../session/widgets/sos_alert_dialog.dart';

class CaregiverSosListener extends StatefulWidget {
  const CaregiverSosListener({super.key, required this.child});

  final Widget child;

  @override
  State<CaregiverSosListener> createState() => CaregiverSosListenerState();
}

class CaregiverSosListenerState extends State<CaregiverSosListener>
    with WidgetsBindingObserver {
  final _service = SosNotificationService();
  Timer? _pollTimer;
  final Set<String> _shownAlertIds = {};
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollAlerts();
    }
  }

  void _startPolling() {
    _pollAlerts();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollAlerts());
  }

  Future<void> _pollAlerts() async {
    if (!mounted || _dialogOpen) return;
    try {
      final alerts = await _service.getPendingAlerts();
      for (final alert in alerts) {
        if (_shownAlertIds.contains(alert.id)) continue;
        _shownAlertIds.add(alert.id);
        await _showAlert(alert);
      }
    } catch (_) {}
  }

  Future<void> _showAlert(SosAlert alert) async {
    if (!mounted) return;
    _dialogOpen = true;

    await showCaregiverSosAlertDialog(
      context: context,
      patientName: alert.patientName,
      message: alert.message,
      onAcknowledged: () => _service.acknowledgeAlert(alert.id),
    );

    _dialogOpen = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
