import '../models/monitoring_session_record.dart';
import '../models/speech_analysis.dart';

class SpeechMetricCard {
  const SpeechMetricCard({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;
}

class SessionInsights {
  const SessionInsights._();

  static String balanceSummary(MonitoringSessionRecord r) {
    if (r.fallEvents > 0) {
      return 'Terdeteksi ${r.fallEvents} kejadian yang mengindikasikan kemungkinan jatuh. Segera periksa kondisi Anda.';
    }
    if (r.impactEvents > 0) {
      return 'Ada ${r.impactEvents} benturan atau guncangan kuat selama sesi. Pantau apakah ada gejala tidak nyaman.';
    }
    if (r.maxTiltDegrees > 45) {
      return 'Postur tubuh cenderung miring hingga ${r.maxTiltDegrees.toStringAsFixed(0)}°. Perhatikan keseimbangan.';
    }
    if (r.maxHeadingDeviationDeg > 25) {
      return 'Gerakan kemiringan cukup signifikan (hingga ${r.maxHeadingDeviationDeg.toStringAsFixed(0)}° dari posisi awal).';
    }
    if (r.avgAvmDeg > 30) {
      return 'Aktivitas gerak cukup aktif selama sesi ini.';
    }
    return 'Gerakan relatif stabil sepanjang sesi. Tidak ada indikasi jatuh atau benturan kuat.';
  }

  static String balanceMovementLevel(MonitoringSessionRecord r) {
    if (r.avgAvmDeg < 10) return 'Tenang';
    if (r.avgAvmDeg < 35) return 'Ringan';
    if (r.avgAvmDeg < 70) return 'Sedang';
    return 'Aktif';
  }

  static String balanceStability(MonitoringSessionRecord r) {
    if (r.fallEvents > 0) return 'Perlu perhatian';
    if (r.impactEvents > 0 || r.maxSvm > 25) return 'Ada guncangan';
    if (r.maxHeadingDeviationDeg > 20) return 'Cukup dinamis';
    return 'Stabil';
  }

  static String balancePosture(MonitoringSessionRecord r) {
    if (r.maxTiltDegrees < 15) return 'Tegak / stabil';
    if (r.maxTiltDegrees < 35) return 'Sedikit miring';
    if (r.maxTiltDegrees < 60) return 'Cukup miring';
    return 'Postur condong';
  }

  /// Narasi singkat speech, dipisah per baris untuk UI card.
  static List<String> speechOverviewLines(MonitoringSessionRecord r) {
    final analysis = r.speechAnalysis;
    final detected = r.speechDetectedSeconds;
    final vad = analysis?.vadActiveSeconds ?? 0;

    if (detected == 0 && vad == 0) {
      return ['Tidak ada suara terdeteksi selama sesi. Normal jika Anda sedang diam.'];
    }

    final pct = (detected / r.durationSeconds * 100).clamp(0, 100);
    final lines = <String>[
      if (pct < 15)
        'Suara terdeteksi sebentar ($detected detik). Sebagian besar sesi dalam diam.'
      else if (pct < 50)
        'Anda berbicara sekitar $detected detik. Aktivitas suara sedang.'
      else
        'Aktivitas suara cukup aktif. Terdeteksi $detected detik berbicara.',
    ];

    if (analysis == null || analysis.offline) return lines;

    if (analysis.dysarthriaRisk != 'unknown' && analysis.dysarthriaRisk != 'none') {
      final dys = _dysarthriaSummary(analysis);
      if (dys.isNotEmpty) lines.add(dys);
    }
    if (analysis.aphasiaRisk != 'unknown' && analysis.aphasiaRisk != 'none') {
      final aph = _aphasiaSummary(analysis);
      if (aph.isNotEmpty) lines.add(aph);
    }
    if (analysis.clinicalSegments.isNotEmpty) {
      lines.add(
        '${analysis.clinicalSegments.length} rekaman momen SOS tersedia. '
        'Putar untuk mendengar deteksi terbata-bata.',
      );
    } else if (analysis.hasClinicalSpeechRisk) {
      lines.add(
        'Indikator klinis terdeteksi, tetapi rekaman belum cukup panjang untuk disimpan.',
      );
    }

    if (lines.length == 1) {
      if (analysis.confirmedSeconds == 0 && vad > 0 && analysis.avgJitter == null) {
        lines.add(
          'Suara terdeteksi, analisis akustik disartria belum cukup. '
          'Coba bicara 3-5 detik per frasa dengan jeda singkat.',
        );
      } else if (analysis.dysarthriaRisk == 'none' && analysis.aphasiaRisk == 'none') {
        lines.add('Parameter bicara dalam rentang normal untuk sesi ini.');
      }
    }

    return lines;
  }

  static String speechSummary(MonitoringSessionRecord r) {
    return speechOverviewLines(r).join(' ');
  }

  static String _dysarthriaSummary(SpeechAnalysisSummary analysis) {
    switch (analysis.dysarthriaRisk) {
      case 'high':
        return 'Indikator disartria tinggi pada jitter, shimmer, dan HNR. Disarankan evaluasi lebih lanjut.';
      case 'medium':
        return 'Ada tanda disartria sedang. Artikulasi atau kontrol vokal kurang stabil.';
      case 'low':
        return 'Tanda disartria ringan terdeteksi.';
      case 'none':
        return 'Parameter akustik disartria dalam rentang normal untuk sesi ini.';
      default:
        return '';
    }
  }

  static String _aphasiaSummary(SpeechAnalysisSummary analysis) {
    final note = analysis.clinicalNotes
        .where((n) =>
            n.contains('disfluensi') ||
            n.contains('terputus') ||
            n.contains('tersendat') ||
            n.contains('micro-pause') ||
            n.contains('Micro-pause'))
        .firstOrNull;
    if (note != null) return note.replaceAll('—', ',');

    switch (analysis.aphasiaRisk) {
      case 'high':
        return 'Disfluensi atau afasia tinggi. Ucapan tersendat atau suku kata sering terputus.';
      case 'medium':
        return 'Pola disfluensi atau afasia sedang. Bicara terbata-bata terdeteksi.';
      case 'low':
        return 'Disfluensi ringan terdeteksi pada fluensi ucapan.';
      default:
        return '';
    }
  }

  static String speechActivity(MonitoringSessionRecord r) {
    if (r.speechDetectedSeconds == 0) return 'Diam';
    final pct = r.speechDetectedSeconds / r.durationSeconds;
    if (pct < 0.15) return 'Jarang';
    if (pct < 0.5) return 'Sedang';
    return 'Aktif';
  }

  static List<SpeechMetricCard> speechMetricCards(MonitoringSessionRecord r) {
    final analysis = r.speechAnalysis;
    if (analysis == null || analysis.offline) return const [];

    final cards = <SpeechMetricCard>[
      SpeechMetricCard(
        label: 'Durasi bicara',
        value: '${analysis.detectedSeconds}s',
        hint: 'VAD ${analysis.vadActiveSeconds}s',
      ),
      SpeechMetricCard(
        label: 'Utterance',
        value: '${analysis.utteranceCount}',
        hint: '${analysis.confirmedSeconds}s terkonfirmasi',
      ),
    ];

    if (analysis.avgJitter != null) {
      cards.add(SpeechMetricCard(
        label: 'Jitter',
        value: '${(analysis.avgJitter! * 100).toStringAsFixed(2)}%',
        hint: 'Stabilitas pitch',
      ));
    }
    if (analysis.avgHnr != null && analysis.avgHnr! > 0) {
      cards.add(SpeechMetricCard(
        label: 'HNR',
        value: '${analysis.avgHnr!.toStringAsFixed(1)} dB',
        hint: 'Rasio harmonik',
      ));
    }
    if (analysis.avgSnrDb > 0) {
      cards.add(SpeechMetricCard(
        label: 'SNR',
        value: '${analysis.avgSnrDb.toStringAsFixed(1)} dB',
        hint: 'Kualitas sinyal',
      ));
    }
    if (analysis.clinicalSegments.isNotEmpty) {
      cards.add(SpeechMetricCard(
        label: 'Rekaman SOS',
        value: '${analysis.clinicalSegments.length}',
        hint: 'Segmen klinis',
      ));
    }

    return cards.take(4).toList();
  }

  static List<String> speechTags(MonitoringSessionRecord r) {
    final tags = <String>[speechActivity(r)];
    final analysis = r.speechAnalysis;
    if (analysis != null && !analysis.offline) {
      tags.add('Skor speech ${analysis.speechScore}');
      tags.add(analysis.dysarthriaRiskLabel);
      tags.add(analysis.aphasiaRiskLabel);
    }
    return tags;
  }

  static List<String> balanceFindings(MonitoringSessionRecord r) {
    final items = <String>[];
    if (r.fallEvents > 0) {
      items.add('${r.fallEvents}x kemungkinan jatuh (benturan kuat lalu tidak bergerak)');
    }
    if (r.impactEvents > 0) {
      items.add('${r.impactEvents}x guncangan atau benturan kuat');
    }
    if (r.maxHeadingDeviationDeg > 15) {
      items.add(
        'Kemiringan maks ${r.maxHeadingDeviationDeg.toStringAsFixed(0)}° dari posisi awal',
      );
    }
    if (r.maxTiltDegrees > 20) {
      items.add('Perubahan postur hingga ${r.maxTiltDegrees.toStringAsFixed(0)}°');
    }
    if (items.isEmpty) {
      items.add('Tidak ada perubahan gerak yang signifikan');
    }
    return items;
  }

  static List<String> speechFindings(MonitoringSessionRecord r) {
    final items = <String>[];
    final analysis = r.speechAnalysis;

    if (analysis != null && !analysis.offline) {
      if (analysis.vadActiveSeconds > 0) {
        items.add('VAD aktif ${analysis.vadActiveSeconds} detik');
      }
      if (analysis.lowQualityCount > 0) {
        items.add('${analysis.lowQualityCount} utterance kualitas rendah (SNR)');
      }
      if (analysis.avgShimmer != null) {
        items.add('Shimmer rata-rata ${(analysis.avgShimmer! * 100).toStringAsFixed(2)}%');
      }
      if (analysis.avgDeviation != null) {
        items.add('Deviasi baseline ${analysis.avgDeviation!.toStringAsFixed(2)}');
      }
      for (final note in analysis.clinicalNotes) {
        final cleaned = note.replaceAll('—', ',');
        if (!items.contains(cleaned)) items.add(cleaned);
      }
    } else if (r.speechDetectedSeconds > 0) {
      items.add('Suara terdeteksi ${r.speechDetectedSeconds} detik');
    } else {
      items.add('Tidak ada suara terkonfirmasi');
    }

    if (r.avgSpeechLevel != 0) {
      items.add('Level energi rata-rata ${r.avgSpeechLevel.toStringAsFixed(0)} dBFS');
    }
    return items;
  }

  static String headingLabel(double radians) {
    final deg = radians * 180 / 3.141592653589793;
    if (deg.abs() < 6) return 'Lurus';
    if (deg < 0) return 'Miring kiri ${deg.abs().toStringAsFixed(0)}°';
    return 'Miring kanan ${deg.toStringAsFixed(0)}°';
  }
}
