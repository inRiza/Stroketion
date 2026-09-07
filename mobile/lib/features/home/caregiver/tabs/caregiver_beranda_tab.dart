import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../models/link_models.dart';
import '../../../../models/session_summary_item.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/link_service.dart';
import '../../../../services/api_client.dart';
import '../../../../services/monitoring_session_api.dart';
import '../../../../services/session_weekly_summary.dart';
import '../../../../widgets/ui/empty_state.dart';
import '../../../session/session_summary_screen.dart';
import '../../widgets/weekly_risk_dashboard.dart';
import '../widgets/caregiver_activity_tile.dart';
import '../widgets/linked_patient_card.dart';

class CaregiverBerandaTab extends StatefulWidget {
  const CaregiverBerandaTab({super.key, this.onOpenNotifications});

  final VoidCallback? onOpenNotifications;

  @override
  State<CaregiverBerandaTab> createState() => _CaregiverBerandaTabState();
}

class _CaregiverBerandaTabState extends State<CaregiverBerandaTab> {
  final _authService = AuthService();
  final _linkService = LinkService();
  final _sessionApi = MonitoringSessionApi();

  String _userName = 'Caregiver';
  List<LinkedPatient> _patients = [];
  List<SessionSummaryItem> _recentActivity = [];
  List<SessionSummaryItem> _selectedPatientSessions = [];
  String? _selectedPatientId;
  int _selectedDayIndex = 6;
  bool _loading = true;
  bool _loadingActivity = false;
  bool _loadingChart = false;
  bool _openingSession = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final user = await _authService.getCurrentUser();
    if (user != null && mounted) {
      setState(() => _userName = user.fullName ?? user.email);
    }

    try {
      final patients = await _linkService.getMyPatients();
      if (!mounted) return;

      final selectedId = _selectedPatientId != null &&
              patients.any((p) => p.id == _selectedPatientId)
          ? _selectedPatientId
          : (patients.isNotEmpty ? patients.first.id : null);

      setState(() {
        _patients = patients;
        _selectedPatientId = selectedId;
      });

      await Future.wait([
        _loadActivity(patients),
        if (selectedId != null) _loadPatientChart(selectedId) else Future.value(),
      ]);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectPatient(String patientId) async {
    if (_selectedPatientId == patientId) return;
    setState(() {
      _selectedPatientId = patientId;
      _selectedDayIndex = 6;
    });
    await _loadPatientChart(patientId);
  }

  Future<void> _loadPatientChart(String patientId) async {
    setState(() => _loadingChart = true);
    try {
      final rows = await _sessionApi.getPatientSessions(patientId, limit: 50);
      if (!mounted) return;
      final patient = _patients.firstWhere((p) => p.id == patientId);
      setState(() {
        _selectedPatientSessions = rows
            .map(
              (row) => SessionSummaryItem.fromJson(
                row,
                patientName: patient.fullName ?? patient.email,
                patientId: patient.id,
              ),
            )
            .toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingChart = false);
    }
  }

  Future<void> _loadActivity(List<LinkedPatient> patients) async {
    if (patients.isEmpty) {
      if (mounted) setState(() => _recentActivity = []);
      return;
    }

    setState(() => _loadingActivity = true);
    try {
      final all = <SessionSummaryItem>[];
      for (final patient in patients) {
        final rows = await _sessionApi.getPatientSessions(patient.id, limit: 5);
        for (final row in rows) {
          all.add(
            SessionSummaryItem.fromJson(
              row,
              patientName: patient.fullName ?? patient.email,
              patientId: patient.id,
            ),
          );
        }
      }
      all.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      if (mounted) setState(() => _recentActivity = all.take(10).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingActivity = false);
    }
  }

  Future<void> _openSessionDetail(SessionSummaryItem item) async {
    if (_openingSession) return;
    setState(() => _openingSession = true);

    try {
      final record = await _sessionApi.getSession(item.id);
      if (!mounted) return;
      if (record == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Detail sesi tidak ditemukan')),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SessionSummaryScreen(record: record)),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat detail sesi')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingSession = false);
    }
  }

  String? get _selectedPatientName {
    if (_selectedPatientId == null) return null;
    for (final patient in _patients) {
      if (patient.id == _selectedPatientId) {
        return patient.fullName ?? patient.email;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasPatients = _patients.isNotEmpty;
    final topInset = MediaQuery.paddingOf(context).top;
    final weeklySummaries = buildWeeklyRiskSummaries(
      _selectedPatientSessions
          .map((s) => SessionRiskPoint(startedAt: s.startedAt, riskLevel: s.riskLevel))
          .toList(),
    );

    return ColoredBox(
      color: AppColors.white,
      child: RefreshIndicator(
        onRefresh: _load,
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
                child: Row(
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
                            'Pantau aktivitas pasien terhubung',
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
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (!hasPatients) ...[
                    const EmptyState(
                      icon: Icons.person_off_outlined,
                      title: 'Belum ada pasien terhubung',
                      subtitle: 'Scan QR pasien di tab Pasien. Pasien perlu menyetujui permintaan.',
                    ),
                  ] else ...[
                    if (_patients.length > 1) ...[
                      Text(
                        'Pilih pasien',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _patients.map((patient) {
                            final selected = patient.id == _selectedPatientId;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(patient.fullName ?? patient.email),
                                selected: selected,
                                onSelected: (_) => _selectPatient(patient.id),
                                selectedColor: AppColors.primarySoft,
                                labelStyle: TextStyle(
                                  color: selected ? AppColors.primary : AppColors.textSecondary,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                ),
                                side: BorderSide(
                                  color: selected ? AppColors.primary : AppColors.border,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_loadingChart)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else
                      WeeklyRiskDashboard(
                        summaries: weeklySummaries,
                        selectedDayIndex: _selectedDayIndex,
                        onDaySelected: (i) => setState(() => _selectedDayIndex = i),
                        title: _selectedPatientName == null
                            ? 'Ringkasan Minggu Ini'
                            : 'Ringkasan ${_selectedPatientName!}',
                        subtitle: 'Distribusi risiko sesi pasien per hari',
                      ),
                    const SizedBox(height: 28),
                    const Text(
                      'Pasien Terpantau',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._patients.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: LinkedPatientCard(
                          patient: p,
                          selected: p.id == _selectedPatientId,
                          onTap: () => _selectPatient(p.id),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Aktivitas Terbaru',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingActivity)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (_recentActivity.isEmpty)
                      const EmptyState(
                        icon: Icons.history,
                        title: 'Belum ada aktivitas',
                        subtitle: 'Aktivitas monitoring muncul setelah pasien menyelesaikan sesi',
                      )
                    else
                      ..._recentActivity.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CaregiverActivityTile(
                            item: item,
                            onTap: _openingSession ? null : () => _openSessionDetail(item),
                          ),
                        ),
                      ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
