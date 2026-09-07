class SpeechClinicalSegment {
  const SpeechClinicalSegment({
    required this.startedAtMs,
    required this.offsetSec,
    required this.durationMs,
    required this.flags,
    this.endedAtMs,
    this.utteranceCount = 1,
    this.snrDb = 0,
    this.vadProbAvg = 0,
    this.jitter,
    this.shimmer,
    this.pcmBase64,
    this.transcript,
    this.semanticRisk = 'unknown',
    this.semanticNotes = const [],
  });

  final double startedAtMs;
  final double? endedAtMs;
  final int offsetSec;
  final int durationMs;
  final int utteranceCount;
  final List<String> flags;
  final double snrDb;
  final double vadProbAvg;
  final double? jitter;
  final double? shimmer;
  final String? pcmBase64;
  final String? transcript;
  final String semanticRisk;
  final List<String> semanticNotes;

  factory SpeechClinicalSegment.fromJson(Map<String, dynamic> json) {
    return SpeechClinicalSegment(
      startedAtMs: (json['started_at_ms'] as num?)?.toDouble() ?? 0,
      endedAtMs: (json['ended_at_ms'] as num?)?.toDouble(),
      offsetSec: json['offset_sec'] as int? ?? 0,
      durationMs: json['duration_ms'] as int? ?? 0,
      utteranceCount: json['utterance_count'] as int? ?? 1,
      flags: (json['flags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      snrDb: (json['snr_db'] as num?)?.toDouble() ?? 0,
      vadProbAvg: (json['vad_prob_avg'] as num?)?.toDouble() ?? 0,
      jitter: (json['jitter'] as num?)?.toDouble(),
      shimmer: (json['shimmer'] as num?)?.toDouble(),
      pcmBase64: json['pcm_base64'] as String?,
      transcript: json['transcript'] as String?,
      semanticRisk: json['semantic_risk'] as String? ?? 'unknown',
      semanticNotes: (json['semantic_notes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  String get label {
    if (flags.contains('disartria') || flags.contains('indikasi_disartria')) {
      return 'Indikasi disartria';
    }
    if (flags.contains('indikasi_disfluensi') ||
        flags.contains('disfluensi') ||
        flags.contains('afasia_proxy')) {
      return 'Indikasi disfluensi';
    }
    return 'Segmen klinis';
  }

  String get timeLabel {
    final start = offsetSec;
    final end = endedAtMs != null
        ? (endedAtMs! / 1000).round()
        : start + (durationMs / 1000).ceil();
    final durSec = (durationMs / 1000).toStringAsFixed(1);
    if (end > start) {
      return '${start}s–${end}s ($durSec detik)';
    }
    return '${start}s (+$durSec detik)';
  }

  String? get semanticSummary {
    if (transcript != null && transcript!.isNotEmpty) {
      return 'Transkrip: "$transcript"';
    }
    if (semanticNotes.isNotEmpty) {
      return semanticNotes.first;
    }
    return null;
  }
}
