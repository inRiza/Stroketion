import 'speech_clinical_segment.dart';

class SpeechAnalysisSummary {
  const SpeechAnalysisSummary({
    this.confirmedSeconds = 0,
    this.vadActiveSeconds = 0,
    this.speechScore = 100,
    this.utteranceCount = 0,
    this.lowQualityCount = 0,
    this.avgSnrDb = 0,
    this.avgDeviation,
    this.avgJitter,
    this.avgShimmer,
    this.avgHnr,
    this.avgPitchStd,
    this.dysarthriaRisk = 'unknown',
    this.aphasiaRisk = 'unknown',
    this.clinicalNotes = const [],
    this.clinicalSegments = const [],
    this.offline = false,
  });

  final int confirmedSeconds;
  final int vadActiveSeconds;
  final int speechScore;
  final int utteranceCount;
  final int lowQualityCount;
  final double avgSnrDb;
  final double? avgDeviation;
  final double? avgJitter;
  final double? avgShimmer;
  final double? avgHnr;
  final double? avgPitchStd;
  final String dysarthriaRisk;
  final String aphasiaRisk;
  final List<String> clinicalNotes;
  final List<SpeechClinicalSegment> clinicalSegments;
  final bool offline;

  int get detectedSeconds {
    final a = confirmedSeconds;
    final b = vadActiveSeconds;
    if (a >= b) return a;
    return b;
  }

  factory SpeechAnalysisSummary.fromJson(Map<String, dynamic> json) {
    final notesRaw = json['clinical_notes'] as List<dynamic>? ?? [];
    final segRaw = json['clinical_segments'] as List<dynamic>? ?? [];
    var summary = SpeechAnalysisSummary(
      confirmedSeconds: json['confirmed_seconds'] as int? ?? 0,
      vadActiveSeconds: json['vad_active_seconds'] as int? ?? 0,
      speechScore: json['speech_score'] as int? ?? 100,
      utteranceCount: json['utterance_count'] as int? ?? 0,
      lowQualityCount: json['low_quality_count'] as int? ?? 0,
      avgSnrDb: (json['avg_snr_db'] as num?)?.toDouble() ?? 0,
      avgDeviation: (json['avg_deviation'] as num?)?.toDouble(),
      avgJitter: (json['avg_jitter'] as num?)?.toDouble(),
      avgShimmer: (json['avg_shimmer'] as num?)?.toDouble(),
      avgHnr: (json['avg_hnr'] as num?)?.toDouble(),
      avgPitchStd: (json['avg_pitch_std'] as num?)?.toDouble(),
      dysarthriaRisk: json['dysarthria_risk'] as String? ?? 'unknown',
      aphasiaRisk: json['aphasia_risk'] as String? ?? 'unknown',
      clinicalNotes: notesRaw.map((e) => e.toString()).toList(),
      clinicalSegments: segRaw
          .map((e) => SpeechClinicalSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      offline: json['offline'] as bool? ?? false,
    );

    final peak = json['peak_clinical_alert'] as Map<String, dynamic>?;
    if (peak != null) {
      final flagsRaw = peak['flags'] as List<dynamic>? ?? [];
      summary = summary.withLiveAlertFallback(
        peakSeverity: peak['severity'] as String?,
        peakReason: peak['reason'] as String?,
        peakFlags: flagsRaw.map((e) => e.toString()).toList(),
      );
    }
    return summary;
  }

  Map<String, dynamic> toJson() => {
        'confirmed_seconds': confirmedSeconds,
        'vad_active_seconds': vadActiveSeconds,
        'speech_score': speechScore,
        'utterance_count': utteranceCount,
        'low_quality_count': lowQualityCount,
        'avg_snr_db': avgSnrDb,
        if (avgDeviation != null) 'avg_deviation': avgDeviation,
        if (avgJitter != null) 'avg_jitter': avgJitter,
        if (avgShimmer != null) 'avg_shimmer': avgShimmer,
        if (avgHnr != null) 'avg_hnr': avgHnr,
        if (avgPitchStd != null) 'avg_pitch_std': avgPitchStd,
        'dysarthria_risk': dysarthriaRisk,
        'aphasia_risk': aphasiaRisk,
        'clinical_notes': clinicalNotes,
        'clinical_segments': clinicalSegments.map((s) => {
              'started_at_ms': s.startedAtMs,
              if (s.endedAtMs != null) 'ended_at_ms': s.endedAtMs,
              'offset_sec': s.offsetSec,
              'duration_ms': s.durationMs,
              'utterance_count': s.utteranceCount,
              'flags': s.flags,
              'snr_db': s.snrDb,
              'vad_prob_avg': s.vadProbAvg,
              if (s.jitter != null) 'jitter': s.jitter,
              if (s.shimmer != null) 'shimmer': s.shimmer,
              if (s.pcmBase64 != null) 'pcm_base64': s.pcmBase64,
              if (s.transcript != null) 'transcript': s.transcript,
              'semantic_risk': s.semanticRisk,
              'semantic_notes': s.semanticNotes,
            }).toList(),
        'offline': offline,
      };

  static const offlineFallback = SpeechAnalysisSummary(offline: true);

  String get dysarthriaRiskLabel {
    switch (dysarthriaRisk) {
      case 'high':
        return 'Disartria: tinggi';
      case 'medium':
        return 'Disartria: sedang';
      case 'low':
        return 'Disartria: rendah';
      case 'none':
        return 'Disartria: normal';
      default:
        return 'Disartria: belum dinilai';
    }
  }

  String get aphasiaRiskLabel {
    switch (aphasiaRisk) {
      case 'high':
        return 'Afasia/fluensi: tinggi';
      case 'medium':
        return 'Afasia/fluensi: sedang';
      case 'low':
        return 'Afasia/fluensi: rendah';
      case 'none':
        return 'Afasia/fluensi: normal';
      default:
        return 'Afasia/fluensi: belum dinilai';
    }
  }

  bool get hasClinicalSpeechRisk =>
      dysarthriaRisk == 'high' ||
      dysarthriaRisk == 'medium' ||
      aphasiaRisk == 'high' ||
      aphasiaRisk == 'medium';

  /// Pastikan ringkasan sesi mencerminkan alert live jika backend terlalu optimis.
  SpeechAnalysisSummary withLiveAlertFallback({
    String? peakSeverity,
    String? peakReason,
    List<String> peakFlags = const [],
  }) {
    if (peakSeverity == null) return this;

    var dys = dysarthriaRisk;
    var aph = aphasiaRisk;
    final notes = List<String>.from(clinicalNotes);

    String bump(String current, String candidate) {
      const rank = {'none': 0, 'unknown': 1, 'low': 2, 'medium': 3, 'high': 4};
      final cur = rank[current] ?? 0;
      final next = rank[candidate] ?? 0;
      if (next > cur) return candidate;
      return current;
    }

    if (peakSeverity == 'high') {
      aph = bump(aph, 'high');
      if (peakFlags.any((f) => f.contains('disartria'))) {
        dys = bump(dys, 'medium');
      }
    }
    // medium peak tidak menaikkan risiko — cukup untuk catatan/rekaman

    if (peakReason != null && peakReason.isNotEmpty && !notes.contains(peakReason)) {
      notes.add(peakReason);
    }

    var score = speechScore;
    if (aph == 'high' || dys == 'high') {
      score = score.clamp(0, 55);
    } else if (aph == 'medium' || dys == 'medium') {
      score = score.clamp(0, 72);
    } else if (aph == 'low' || dys == 'low') {
      score = score.clamp(0, 85);
    }

    return SpeechAnalysisSummary(
      confirmedSeconds: confirmedSeconds,
      vadActiveSeconds: vadActiveSeconds,
      speechScore: score,
      utteranceCount: utteranceCount,
      lowQualityCount: lowQualityCount,
      avgSnrDb: avgSnrDb,
      avgDeviation: avgDeviation,
      avgJitter: avgJitter,
      avgShimmer: avgShimmer,
      avgHnr: avgHnr,
      avgPitchStd: avgPitchStd,
      dysarthriaRisk: dys,
      aphasiaRisk: aph,
      clinicalNotes: notes,
      clinicalSegments: clinicalSegments,
      offline: false,
    );
  }
}

class SpeechLiveMetrics {
  const SpeechLiveMetrics({
    this.speechActive = false,
    this.energyDbfs = -60,
    this.vadProb = 0,
    this.connected = false,
    this.loading = false,
    this.offline = false,
    this.offlineReason,
  });

  final bool speechActive;
  final double energyDbfs;
  final double vadProb;
  final bool connected;
  final bool loading;
  final bool offline;
  final String? offlineReason;

  String get statusLabel {
    if (offline) {
      return offlineReason ?? 'Analisis suara offline';
    }
    if (loading) return 'Memuat model speech...';
    if (!connected) return 'Menghubungkan speech...';
    if (speechActive) return 'Suara terdeteksi (VAD)';
    if (vadProb > 0.2) return 'Menunggu konfirmasi...';
    return 'Tidak ada suara';
  }
}
