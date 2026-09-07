import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../models/monitoring_session_record.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/patient_session_loader.dart';
import '../../../../services/session_refresh.dart';
import '../../../../services/session_weekly_summary.dart';
import '../../../../widgets/ui/wireframe_skeleton.dart';
import '../../../session/session_history_screen.dart';
import '../../../session/session_setup_sheet.dart';
import '../../../session/session_summary_screen.dart';
import '../../../session/widgets/session_history_tile.dart';
import '../../widgets/weekly_risk_dashboard.dart';
import '../widgets/start_session_button.dart';

class PatientBerandaTab extends StatefulWidget {
  const PatientBerandaTab({super.key, this.onOpenNotifications});

  final VoidCallback? onOpenNotifications;

  @override
  PatientBerandaTabState createState() => PatientBerandaTabState();
}

class PatientBerandaTabState extends State<PatientBerandaTab> {
  final _authService = AuthService();
  final _sessionLoader = PatientSessionLoader();
  bool _openingSession = false;

  String _userName = 'Pasien';
  int _selectedDayIndex = 6;
  List<MonitoringSessionRecord> _recentSessions = [];
  List<MonitoringSessionRecord> _chartSessions = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    SessionRefresh.onSessionSaved = _loadRecentSessions;
    _loadUser();
    _loadRecentSessions();
  }

  @override
  void dispose() {
    if (SessionRefresh.onSessionSaved == _loadRecentSessions) {
      SessionRefresh.onSessionSaved = null;
    }
    super.dispose();
  }

  void reloadHistory() => _loadRecentSessions();

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentUser();
    if (user != null && mounted) {
      setState(() => _userName = user.fullName ?? user.email);
    }
  }

  Future<void> _loadRecentSessions() async {
    setState(() => _loadingHistory = true);
    final records = await _sessionLoader.loadMerged(limit: 50);
    if (mounted) {
      setState(() {
        _chartSessions = records;
        _recentSessions = records.take(5).toList();
        _loadingHistory = false;
      });
    }
  }

  Future<void> _openSessionDetail(MonitoringSessionRecord record) async {
    if (_openingSession) return;
    setState(() => _openingSession = true);

    try {
      final detail = await _sessionLoader.resolveDetail(record);
      if (!mounted) return;
      if (detail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Detail sesi tidak ditemukan')),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionSummaryScreen(record: detail),
        ),
      );
      _loadRecentSessions();
    } finally {
      if (mounted) setState(() => _openingSession = false);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SessionHistoryScreen()),
    );
    _loadRecentSessions();
  }

  @override
  Widget build(BuildContext context) {
    final weeklySummaries = buildWeeklyRiskSummaries(
      _chartSessions
          .map((r) => SessionRiskPoint(startedAt: r.startedAt, riskLevel: r.riskLevel))
          .toList(),
    );
    final topInset = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: AppColors.white,
      child: RefreshIndicator(
        onRefresh: _loadRecentSessions,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 24),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.xl),
                    bottomRight: Radius.circular(AppRadius.xl),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, $_userName',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(DateTime.now()),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.white.withValues(alpha: 0.82),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onOpenNotifications != null)
                          IconButton(
                            onPressed: widget.onOpenNotifications,
                            icon: const Icon(Icons.notifications_outlined),
                            color: AppColors.white,
                            tooltip: 'Notifikasi',
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    StartSessionButton(
                      onStart: () => showSessionSetupSheet(context),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  WeeklyRiskDashboard(
                    summaries: weeklySummaries,
                    selectedDayIndex: _selectedDayIndex,
                    onDaySelected: (i) => setState(() => _selectedDayIndex = i),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Riwayat Aktivitas',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (!_loadingHistory && _recentSessions.isNotEmpty)
                        GestureDetector(
                          onTap: _openHistory,
                          child: const Text(
                            'Lihat lebih lengkap',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingHistory)
                    const SessionHistorySkeleton(count: 3)
                  else if (_recentSessions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Belum ada sesi. Mulai sesi pertama Anda!',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    )
                  else
                    ..._recentSessions.map((record) {
                      return SessionHistoryTile(
                        record: record,
                        onTap: _openingSession
                            ? null
                            : () => _openSessionDetail(record),
                      );
                    }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
