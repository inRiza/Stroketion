import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../models/monitoring_session_record.dart';
import '../../models/session_timeline.dart';
import '../../services/session_gps_service.dart';
import '../../services/session_insights.dart';
import '../../widgets/ui/soft_card.dart';
import 'session_detail_screen.dart';
import 'widgets/balance_timeline_chart.dart';
import 'widgets/session_map_view.dart';
import 'widgets/speech_clinical_segments_list.dart';
import 'widgets/speech_insight_panel.dart';

class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({super.key, required this.record});

  final MonitoringSessionRecord record;

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}j ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}d';
    }
    return '${d.inSeconds} detik';
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  }

  bool _hasSpeechClinicalRisk(MonitoringSessionRecord record) {
    final analysis = record.speechAnalysis;
    if (analysis == null || analysis.offline) return false;
    return analysis.hasClinicalSpeechRisk;
  }

  Color _riskColor(SessionRiskLevel level) {
    switch (level) {
      case SessionRiskLevel.high:
        return AppColors.primaryDark;
      case SessionRiskLevel.medium:
        return AppColors.primary;
      case SessionRiskLevel.low:
        return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        iconTheme: const IconThemeData(color: AppColors.white),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Ringkasan Sesi',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    _ContextBadge(icon: Icons.place_outlined, label: record.location.label),
                    _ContextBadge(icon: Icons.directions_run_outlined, label: record.activity.label),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sesi selesai',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatDuration(record.duration),
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDateTime(record.startedAt),
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              SoftCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ScoreCard(
                            label: 'Skor',
                            value: '${record.overallScore}',
                            sub: 'Overall',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ScoreCard(
                            label: SessionRiskLevelLabel.typeLabel,
                            value: record.riskLevel.levelLabel,
                            sub: 'Level risiko',
                            valueColor: _riskColor(record.riskLevel),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SessionDetailScreen(record: record),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.background,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.button),
                          ),
                        ),
                        icon: const Icon(Icons.analytics_outlined, size: 18),
                        label: const Text(
                          'Lihat detail perhitungan',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Grafik Balance'),
              const SizedBox(height: 10),
              SoftCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: BalanceTimelineChart(timeline: record.timeline, borderless: true),
                ),
              ),
              if (record.gpsActive && record.route.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionTitle('Rute Perjalanan'),
                const SizedBox(height: 8),
                Text(
                  'Jarak ${formatDistance(record.distanceMeters)}',
                  style: TextStyle(fontSize: 13, color: AppColors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 10),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: SessionMapView(
                      route: record.route,
                      height: 220,
                      interactive: true,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const _SectionTitle('Balance'),
              const SizedBox(height: 10),
              SoftCard(
                child: _BalanceInsightBody(record: record),
              ),
              const SizedBox(height: 20),
              SpeechInsightPanel(
                record: record,
                highlight: _hasSpeechClinicalRisk(record),
              ),
              if (record.speechAnalysis?.clinicalSegments.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                SoftCard(
                  child: SpeechClinicalSegmentsList(
                    segments: record.speechAnalysis!.clinicalSegments,
                  ),
                ),
              ] else if (_hasSpeechClinicalRisk(record)) ...[
                const SizedBox(height: 12),
                SoftCard(
                  child: Text(
                    'SOS terdeteksi, tetapi audio momen tersebut belum cukup untuk disimpan '
                    '(minimal ~5 detik di sekitar deteksi).',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.value,
    required this.sub,
    this.valueColor,
  });

  final String label;
  final String value;
  final String sub;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ContextBadge extends StatelessWidget {
  const _ContextBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF8E0000),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
      ),
    );
  }
}

class _BalanceInsightBody extends StatelessWidget {
  const _BalanceInsightBody({required this.record});

  final MonitoringSessionRecord record;

  @override
  Widget build(BuildContext context) {
    final tags = [
      SessionInsights.balanceStability(record),
      SessionInsights.balanceMovementLevel(record),
      SessionInsights.balancePosture(record),
    ];
    final findings = SessionInsights.balanceFindings(record);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.accessibility_new_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                SessionInsights.balanceSummary(record),
                style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags
              .map(
                (t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    t,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        Text(
          'Yang terdeteksi',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        ...findings.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(f, style: const TextStyle(fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
