import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/monitoring_session_record.dart';
import 'widgets/balance_timeline_chart.dart';
import 'widgets/session_map_view.dart';
import '../../services/session_gps_service.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.record});

  final MonitoringSessionRecord record;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Detail Perhitungan')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IntroCard(
                text:
                    'Angka di bawah adalah metrik teknis dari sensor perangkat, '
                    'sesuai pipeline motion (SVM, AVM, orientasi θ).',
              ),
              const SizedBox(height: 20),
              _ScoreRow(record: record),
              const SizedBox(height: 20),
              BalanceTimelineChart(timeline: record.timeline, height: 180),
              if (record.gpsActive && record.route.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionTitle('Rute GPS'),
                const SizedBox(height: 8),
                Text(
                  'Jarak ${formatDistance(record.distanceMeters)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                SessionMapView(route: record.route, height: 200, interactive: true),
              ],
              const SizedBox(height: 20),
              const _SectionTitle('Balance (Sensor Motion)'),
              const SizedBox(height: 12),
              _StatGrid(
                children: [
                  _StatCard(
                    label: 'SVM rata-rata (m/s²)',
                    desc: 'Magnitudo percepatan termasuk gravitasi',
                    value: record.avgSvm.toStringAsFixed(2),
                    icon: Icons.speed_outlined,
                  ),
                  _StatCard(
                    label: 'SVM maksimum (m/s²)',
                    desc: 'Puncak g-force, impact threshold sekitar 25',
                    value: record.maxSvm.toStringAsFixed(2),
                    icon: Icons.bolt_outlined,
                    highlight: record.maxSvm > 25,
                  ),
                  _StatCard(
                    label: 'AVM rata-rata (°/s)',
                    desc: 'Kecepatan sudut rotasi gyroscope',
                    value: record.avgAvmDeg.toStringAsFixed(1),
                    icon: Icons.sync_outlined,
                  ),
                  _StatCard(
                    label: 'AVM maksimum (°/s)',
                    desc: 'Rotasi tercepat, threshold jatuh sekitar 200°/s',
                    value: record.maxAvmDeg.toStringAsFixed(1),
                    icon: Icons.rotate_right_outlined,
                    highlight: record.maxAvmDeg > 200,
                  ),
                  _StatCard(
                    label: 'Orientasi maks (°)',
                    desc: 'Kemiringan postur dari arctan2(a_y, a_z)',
                    value: record.maxTiltDegrees.toStringAsFixed(1),
                    icon: Icons.screen_rotation_outlined,
                  ),
                  _StatCard(
                    label: 'Kemiringan arah maks (°)',
                    desc: 'Deviasi dari posisi lurus saat mulai',
                    value: record.maxHeadingDeviationDeg.toStringAsFixed(1),
                    icon: Icons.explore_outlined,
                  ),
                  _StatCard(
                    label: 'Kemungkinan jatuh',
                    value: '${record.fallEvents}',
                    icon: Icons.warning_amber_outlined,
                    highlight: record.fallEvents > 0,
                  ),
                  _StatCard(
                    label: 'Guncangan terdeteksi',
                    value: '${record.impactEvents}',
                    icon: Icons.sensors_outlined,
                    highlight: record.impactEvents > 0,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Speech (Sensor Mikrofon)'),
              const SizedBox(height: 12),
              _StatGrid(
                children: [
                  _StatCard(
                    label: 'Durasi suara (detik)',
                    value: '${record.speechDetectedSeconds}',
                    icon: Icons.graphic_eq,
                  ),
                  _StatCard(
                    label: 'Level rata-rata (dB)',
                    value: record.avgSpeechLevel.toStringAsFixed(0),
                    icon: Icons.volume_up_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.record});

  final MonitoringSessionRecord record;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ScoreTile(label: 'Overall', value: '${record.overallScore}'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScoreTile(label: 'Balance', value: '${record.balanceScore}'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScoreTile(label: 'Speech', value: '${record.speechScore}'),
        ),
      ],
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
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
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: children,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.desc,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? desc;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          if (desc != null) ...[
            const SizedBox(height: 2),
            Text(
              desc!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, height: 1.2),
            ),
          ],
        ],
      ),
    );
  }
}
