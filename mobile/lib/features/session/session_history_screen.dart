import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/monitoring_session_record.dart';
import '../../services/patient_session_loader.dart';
import '../../widgets/ui/app_text_field.dart';
import '../../widgets/ui/wireframe_skeleton.dart';
import 'session_summary_screen.dart';
import 'widgets/session_history_tile.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  final _loader = PatientSessionLoader();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  Timer? _debounce;
  List<MonitoringSessionRecord> _allRecords = [];
  List<MonitoringSessionRecord> _records = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  bool _openingSession = false;

  SessionLocation? _locationFilter;
  SessionActivity? _activityFilter;

  static const _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetch(reset: true);
    });
  }

  void _onScroll() {
    if (_loading || _loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      _fetch(reset: false);
    }
  }

  Future<void> _fetch({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _offset = 0;
        _hasMore = true;
      });
      _allRecords = await _loader.loadMerged(limit: 200);
    } else {
      setState(() => _loadingMore = true);
    }

    var filtered = _allRecords;

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((r) {
        return r.location.label.toLowerCase().contains(query) ||
            r.activity.label.toLowerCase().contains(query);
      }).toList();
    }

    if (_locationFilter != null) {
      filtered = filtered.where((r) => r.location == _locationFilter).toList();
    }

    if (_activityFilter != null) {
      filtered = filtered.where((r) => r.activity == _activityFilter).toList();
    }

    final start = reset ? 0 : _offset;
    final end = (start + _pageSize).clamp(0, filtered.length);
    final batch = start >= filtered.length
        ? <MonitoringSessionRecord>[]
        : filtered.sublist(start, end);

    if (!mounted) return;

    setState(() {
      if (reset) {
        _records = batch;
        _loading = false;
      } else {
        _records = [..._records, ...batch];
        _loadingMore = false;
      }
      _offset = _records.length;
      _hasMore = end < filtered.length;
    });
  }

  Future<void> _openSessionDetail(MonitoringSessionRecord record) async {
    if (_openingSession) return;
    setState(() => _openingSession = true);

    try {
      final detail = await _loader.resolveDetail(record);
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
    } finally {
      if (mounted) setState(() => _openingSession = false);
    }
  }

  void _setLocationFilter(SessionLocation? value) {
    setState(() => _locationFilter = _locationFilter == value ? null : value);
    _fetch(reset: true);
  }

  void _setActivityFilter(SessionActivity? value) {
    setState(() => _activityFilter = _activityFilter == value ? null : value);
    _fetch(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Riwayat Sesi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: AppTextField(
              controller: _searchController,
              hint: 'Cari lokasi atau aktivitas...',
              prefixIcon: Icons.search,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _FilterChip(
                  label: 'Di rumah',
                  selected: _locationFilter == SessionLocation.home,
                  onTap: () => _setLocationFilter(SessionLocation.home),
                ),
                _FilterChip(
                  label: 'Di luar',
                  selected: _locationFilter == SessionLocation.outdoor,
                  onTap: () => _setLocationFilter(SessionLocation.outdoor),
                ),
                _FilterChip(
                  label: 'Sehari-hari',
                  selected: _activityFilter == SessionActivity.daily,
                  onTap: () => _setActivityFilter(SessionActivity.daily),
                ),
                _FilterChip(
                  label: 'Olahraga',
                  selected: _activityFilter == SessionActivity.exercise,
                  onTap: () => _setActivityFilter(SessionActivity.exercise),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: SessionHistorySkeleton(count: 5),
                  )
                : _records.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada sesi ditemukan.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: _records.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _records.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          final record = _records[index];
                          return SessionHistoryTile(
                            record: record,
                            onTap: _openingSession
                                ? null
                                : () => _openSessionDetail(record),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
