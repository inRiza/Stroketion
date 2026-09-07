import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../models/monitoring_session_record.dart';
import '../../../services/session_insights.dart';
import '../../../widgets/ui/soft_card.dart';

class SpeechInsightPanel extends StatelessWidget {
  const SpeechInsightPanel({
    super.key,
    required this.record,
    this.highlight = false,
  });

  final MonitoringSessionRecord record;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final analysis = record.speechAnalysis;
    final overview = SessionInsights.speechOverviewLines(record);
    final metrics = SessionInsights.speechMetricCards(record);
    final findings = SessionInsights.speechFindings(record);

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: highlight ? AppColors.primarySoft : AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.record_voice_over_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Speech',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (analysis != null && !analysis.offline)
                _RiskBadge(label: 'Skor ${analysis.speechScore}', tone: _scoreTone(analysis.speechScore)),
            ],
          ),
          const SizedBox(height: 14),
          ...overview.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (analysis != null && !analysis.offline) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RiskBadge(
                  label: analysis.dysarthriaRiskLabel,
                  tone: _riskTone(analysis.dysarthriaRisk),
                ),
                _RiskBadge(
                  label: analysis.aphasiaRiskLabel,
                  tone: _riskTone(analysis.aphasiaRisk),
                ),
                _RiskBadge(
                  label: SessionInsights.speechActivity(record),
                  tone: BadgeTone.neutral,
                ),
              ],
            ),
          ],
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: metrics.map((m) => _MetricTile(card: m)).toList(),
            ),
          ],
          if (findings.isNotEmpty) ...[
            const SizedBox(height: 16),
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
                      child: Text(
                        f,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  BadgeTone _scoreTone(int score) {
    if (score >= 75) return BadgeTone.success;
    if (score >= 55) return BadgeTone.warning;
    return BadgeTone.danger;
  }

  BadgeTone _riskTone(String risk) {
    switch (risk) {
      case 'high':
        return BadgeTone.danger;
      case 'medium':
        return BadgeTone.warning;
      case 'low':
        return BadgeTone.neutral;
      case 'none':
        return BadgeTone.success;
      default:
        return BadgeTone.neutral;
    }
  }
}

enum BadgeTone { success, warning, danger, neutral }

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.card});

  final SpeechMetricCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            card.value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            card.hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.label, required this.tone});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.success => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      BadgeTone.warning => (AppColors.primarySoft, AppColors.primaryDark),
      BadgeTone.danger => (const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      BadgeTone.neutral => (AppColors.background, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
