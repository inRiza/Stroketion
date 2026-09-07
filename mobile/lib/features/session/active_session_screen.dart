import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/monitoring_session_record.dart';
import '../../services/monitoring_session_api.dart';
import '../../services/session_history_storage.dart';
import '../../services/session_refresh.dart';
import '../../services/session_sensor_service.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_confirm_dialog.dart';
import 'session_summary_screen.dart';
import '../../services/sos_service.dart';
import 'widgets/motion_compass.dart';
import 'widgets/session_map_view.dart';
import 'widgets/sos_alert_dialog.dart';
import 'widgets/sos_call_chain_sheet.dart';
import 'widgets/speech_waveform.dart';

class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({super.key, required this.setup});

  final SessionSetup setup;

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  final _sensorService = SessionSensorService();
  final _storage = SessionHistoryStorage();
  final _sosService = SosService();
  final _sessionApi = MonitoringSessionApi();
  bool _starting = true;
  String? _error;
  bool _sosDialogOpen = false;

  bool get _isOutdoor => widget.setup.location == SessionLocation.outdoor;

  @override
  void initState() {
    super.initState();
    _sensorService.addListener(_onSensorUpdate);
    _sensorService.onHighRisk = _onHighRisk;
    _initSession();
  }

  Future<void> _onHighRisk(String reason) async {
    if (!mounted || _sosDialogOpen) return;
    _sosDialogOpen = true;

    await showSosAlertDialog(
      context: context,
      reason: reason,
      onResolved: (callSos) async {
        _sosDialogOpen = false;
        if (!callSos || !mounted) return;
        await _sosService.notifyCaregivers(message: reason);
        if (!mounted) return;
        await showSosCallChainDialog(context: context, sosService: _sosService);
      },
    );

    _sosDialogOpen = false;
    await _sensorService.resumeSpeechAfterSos();
    if (mounted) setState(() {});
  }

  Future<void> _initSession() async {
    final ok = await _sensorService.start(setup: widget.setup);
    if (!mounted) return;
    setState(() {
      _starting = false;
      if (!ok) _error = 'Izin mikrofon diperlukan untuk sesi monitoring.';
    });
  }

  void _onSensorUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _finishSession() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Selesai sesi?',
      message: 'Ringkasan sesi akan ditampilkan.',
      confirmLabel: 'Selesai',
      cancelLabel: 'Batal',
    );

    if (confirmed != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Menyusun ringkasan sesi...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final record = await _sensorService.stop(setup: widget.setup);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (record == null || !mounted) return;

    await _storage.save(record);
    try {
      await _sessionApi.uploadSession(record);
    } catch (_) {}
    SessionRefresh.notifySaved();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SessionSummaryScreen(record: record),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _sensorService.removeListener(_onSensorUpdate);
    _sensorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _sensorService.metrics;
    final gps = _sensorService.gps;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sesi Aktif'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _formatDuration(_sensorService.elapsed),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _starting
          ? const Center(child: CircularProgressIndicator(color: AppColors.white))
          : _error != null
              ? _ErrorBody(message: _error!, onBack: () => Navigator.pop(context))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      children: [
                        if (_isOutdoor) ...[
                          SessionMapView(
                            route: gps.route,
                            current: gps.current,
                            height: 200,
                            showGpsBadge: metrics.gpsActive,
                            distanceMeters: metrics.distanceMeters,
                          ),
                          if (!metrics.gpsActive) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'GPS tidak aktif. Aktifkan izin lokasi untuk melacak rute.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _Tag(label: widget.setup.location.label),
                                  const SizedBox(width: 8),
                                  _Tag(label: widget.setup.activity.label),
                                ],
                              ),
                              if (metrics.fallState != FallState.normal) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    metrics.fallState.label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              MotionCompass(
                                displayHeadingRadians: metrics.displayHeadingRadians,
                                headingLabel: metrics.headingLabel,
                                avmIntensity: metrics.avmIntensity,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SpeechWaveform(
                          samples: metrics.waveform,
                          speechActive: metrics.speechActive,
                          speechLevel: metrics.speechLevel,
                          statusLabel: metrics.speechStatusLabel,
                          offline: _sensorService.speechOffline,
                        ),
                        const SizedBox(height: 20),
                        AppButton(
                          label: 'Selesai Sesi',
                          icon: Icons.stop_circle_outlined,
                          onPressed: _finishSession,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mic_off_outlined, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          AppButton(label: 'Kembali', variant: AppButtonVariant.neutral, onPressed: onBack),
        ],
      ),
    );
  }
}
