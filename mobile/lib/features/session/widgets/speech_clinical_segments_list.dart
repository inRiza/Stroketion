import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/speech_clinical_segment.dart';

Uint8List _pcm16ToWav(Uint8List pcm, {int sampleRate = 16000}) {
  final dataSize = pcm.length;
  final fileSize = 36 + dataSize;
  final buffer = ByteData(44 + dataSize);
  void writeStr(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      buffer.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeStr(0, 'RIFF');
  buffer.setUint32(4, fileSize, Endian.little);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  buffer.setUint32(16, 16, Endian.little);
  buffer.setUint16(20, 1, Endian.little);
  buffer.setUint16(22, 1, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, sampleRate * 2, Endian.little);
  buffer.setUint16(32, 2, Endian.little);
  buffer.setUint16(34, 16, Endian.little);
  writeStr(36, 'data');
  buffer.setUint32(40, dataSize, Endian.little);

  final out = Uint8List(44 + dataSize);
  out.setRange(0, 44, buffer.buffer.asUint8List(0, 44));
  out.setRange(44, 44 + dataSize, pcm);
  return out;
}

class SpeechClinicalSegmentsList extends StatefulWidget {
  const SpeechClinicalSegmentsList({super.key, required this.segments});

  final List<SpeechClinicalSegment> segments;

  @override
  State<SpeechClinicalSegmentsList> createState() =>
      _SpeechClinicalSegmentsListState();
}

class _SpeechClinicalSegmentsListState extends State<SpeechClinicalSegmentsList> {
  final _player = AudioPlayer();
  int? _playingIndex;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(int index) async {
    final seg = widget.segments[index];
    if (seg.pcmBase64 == null || seg.pcmBase64!.isEmpty) return;

    setState(() => _playingIndex = index);
    try {
      final pcm = base64Decode(seg.pcmBase64!);
      final wav = _pcm16ToWav(pcm);
      await _player.stop();
      await _player.play(BytesSource(wav));
    } finally {
      if (mounted) setState(() => _playingIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.segments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rekaman segmen klinis',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...widget.segments.asMap().entries.map((entry) {
          final i = entry.key;
          final seg = entry.value;
          final canPlay = seg.pcmBase64 != null && seg.pcmBase64!.isNotEmpty;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: canPlay ? () => _play(i) : null,
                  icon: Icon(
                    _playingIndex == i ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${seg.label} · ${seg.timeLabel}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        seg.flags.join(', '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (seg.utteranceCount > 1)
                        Text(
                          '${seg.utteranceCount} utterance digabung',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (seg.semanticSummary != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            seg.semanticSummary!,
                            style: TextStyle(
                              fontSize: 11,
                              color: seg.semanticRisk == 'medium'
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
