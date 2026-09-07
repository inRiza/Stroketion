import base64
from dataclasses import dataclass

import numpy as np

from app.speech.config import speech_settings
from app.speech.fluency import analyze_intra_utterance_fluency, session_disfluency_summary
from app.speech.models import AcousticFeatures, SegmentQuality, UtteranceResult

_RISK_RANK = {"none": 0, "unknown": 1, "low": 2, "medium": 3, "high": 4}
_ALERT_RANK = {"low": 1, "medium": 2, "high": 3}


def _max_risk(current: str, candidate: str) -> str:
    if _RISK_RANK.get(candidate, 0) > _RISK_RANK.get(current, 0):
        return candidate
    return current


def track_peak_clinical_alert(state, alert: dict) -> None:
    """Simpan alert live terkuat — dipakai saat finalize ringkasan."""
    severity = alert.get("severity", "low")
    prev = getattr(state, "peak_clinical_alert", None)
    if prev is None or _ALERT_RANK.get(severity, 0) > _ALERT_RANK.get(prev.get("severity", "low"), 0):
        state.peak_clinical_alert = alert


def finalize_clinical_risks(
    utterances: list[UtteranceResult],
    dys_risk: str,
    dys_notes: list[str],
    aph_risk: str,
    aph_notes: list[str],
    *,
    peak_alert: dict | None = None,
) -> tuple[str, list[str], str, list[str]]:
    """Gabungkan sinyal live + fluensi internal ke risiko sesi final."""
    dys_notes = list(dys_notes)
    aph_notes = list(aph_notes)

    flu = session_disfluency_summary(utterances)
    if flu["session_disfluency"] == "high":
        aph_risk = _max_risk(aph_risk, "high")
        aph_notes.append(
            f"Disfluensi berat — {flu['total_micro_pauses']} micro-pause "
            f"pada {flu['high_utterances']} utterance"
        )
    elif flu["session_disfluency"] == "medium":
        aph_risk = _max_risk(aph_risk, "medium")
        aph_notes.append(
            f"Pola tersendat — {flu['total_micro_pauses']} micro-pause terdeteksi"
        )

    if peak_alert:
        reason = peak_alert.get("reason")
        flags = peak_alert.get("flags") or []
        if reason and reason not in aph_notes:
            aph_notes.append(reason)
        if peak_alert.get("severity") == "high":
            aph_risk = _max_risk(aph_risk, "high")
            if any("disartria" in f for f in flags):
                dys_risk = _max_risk(dys_risk, "medium")

    return dys_risk, dys_notes, aph_risk, aph_notes


def utterance_dysarthria_flags(features: AcousticFeatures | None) -> list[str]:
    if features is None:
        return []
    flags: list[str] = []
    if features.jitter > 0.009:
        flags.append("jitter_tinggi")
    if features.shimmer > 0.05:
        flags.append("shimmer_tinggi")
    if features.hnr < 14:
        flags.append("hnr_rendah")
    if features.pitch_std > 35:
        flags.append("pitch_tidak_stabil")
    return flags


def assess_dysarthria(
    utterances: list[UtteranceResult],
    avg_deviation: float | None,
    has_baseline: bool,
    *,
    low_quality_count: int = 0,
    vad_segment_count: int = 0,
    vad_active_seconds: int = 0,
) -> tuple[str, list[str]]:
    notes: list[str] = []
    with_features = [u for u in utterances if u.features is not None]
    flu = session_disfluency_summary(utterances)

    if not with_features:
        if low_quality_count >= 3 and vad_active_seconds >= 8:
            notes.append(
                "Disartria (proxy): ucapan terfragmentasi/ SNR rendah — profil jitter/shimmer belum terukur"
            )
            if vad_segment_count >= 8:
                return "medium", notes
            return "low", notes
        return "unknown", notes

    features = [u.features for u in with_features if u.features is not None]
    avg = _avg_features(features)
    risk_score = 0

    if has_baseline and avg_deviation is not None:
        if avg_deviation > 2.0:
            risk_score += 3
            notes.append(
                f"Deviasi akustik tinggi dari baseline ({avg_deviation:.2f})"
            )
        elif avg_deviation > 1.0:
            risk_score += 2
            notes.append(f"Deviasi akustik sedang dari baseline ({avg_deviation:.2f})")
        elif avg_deviation > 0.5:
            risk_score += 1
    else:
        notes.append("Baseline suara belum dikalibrasi — memakai ambang absolut")

    jitter_pct = avg["jitter"] * 100
    if jitter_pct > 1.2:
        risk_score += 2
        notes.append(f"Jitter tinggi ({jitter_pct:.2f}%) — indikator disartria")
    elif jitter_pct > 0.6:
        risk_score += 1

    shimmer_pct = avg["shimmer"] * 100
    if shimmer_pct > 5.0:
        risk_score += 2
        notes.append(f"Shimmer tinggi ({shimmer_pct:.2f}%) — indikator disartria")
    elif shimmer_pct > 3.0:
        risk_score += 1

    if avg["hnr"] < 14:
        risk_score += 2
        notes.append(f"HNR rendah ({avg['hnr']:.1f} dB)")
    elif avg["hnr"] < 20:
        risk_score += 1

    if avg["pitch_std"] > 35:
        risk_score += 1
        notes.append(f"Variabilitas pitch tinggi ({avg['pitch_std']:.0f} Hz)")

    if flu["session_disfluency"] == "high":
        risk_score += 3
        notes.append("Disfluensi internal berat — kontrol artikulasi/fluensi terganggu")
    elif flu["session_disfluency"] == "medium":
        risk_score += 2
        notes.append("Pola tersendat terdeteksi pada fluensi internal")

    if risk_score >= 5:
        return "high", notes
    if risk_score >= 3:
        return "medium", notes
    if risk_score >= 1:
        return "low", notes
    notes.append("Parameter akustik dalam rentang normal sesi ini")
    return "none", notes


def assess_aphasia_proxy(
    vad_active_seconds: int,
    confirmed_seconds: int,
    analyzable_count: int,
    total_utterance_count: int,
    low_quality_count: int,
    vad_segment_count: int,
    duration_seconds: int,
    utterances: list[UtteranceResult] | None = None,
) -> tuple[str, list[str]]:
    notes: list[str] = []
    if vad_active_seconds == 0 or duration_seconds <= 0:
        return "unknown", notes

    speech_ratio = vad_active_seconds / duration_seconds

    # fluensi internal: a-a-a-aku dalam satu utterance
    if utterances:
        flu_summary = session_disfluency_summary(utterances)
        if flu_summary["session_disfluency"] == "high":
            notes.append(
                f"Disfluensi berat — {flu_summary['total_micro_pauses']} micro-pause "
                f"({flu_summary['high_utterances']} utterance berat)"
            )
            return "high", notes
        if flu_summary["session_disfluency"] == "medium":
            notes.append(
                f"Pola disfluensi internal — {flu_summary['total_micro_pauses']} micro-pause "
                f"({flu_summary['medium_utterances']} utterance sedang/berat)"
            )
            return "medium", notes
        if flu_summary["session_disfluency"] == "low":
            notes.append(
                f"Micro-pause berulang terdeteksi ({flu_summary['total_micro_pauses']}x) — disfluensi ringan"
            )
            return "low", notes

    # VAD segment jauh lebih banyak dari utterance = suku kata terputus-putus
    if total_utterance_count >= 1 and vad_segment_count >= 6:
        toggle_ratio = vad_segment_count / max(total_utterance_count, 1)
        if toggle_ratio >= 3.5 and vad_active_seconds >= 4:
            notes.append(
                f"Ucapan tersendat — {vad_segment_count} aktivasi VAD pada {total_utterance_count} frasa"
            )
            return "medium", notes

    if total_utterance_count >= 4 and analyzable_count == 0 and vad_active_seconds >= 8:
        notes.append(f"{total_utterance_count} segmen terfragmentasi — pola disfluensi/ afasia")
        return "medium", notes

    if vad_segment_count >= 6 and vad_active_seconds >= 8:
        avg_seg_sec = vad_active_seconds / vad_segment_count
        if avg_seg_sec < 2.0:
            notes.append(
                f"Ucapan sering terputus ({vad_segment_count} segmen, ~{avg_seg_sec:.1f}s/segmen)"
            )
            return "medium" if vad_segment_count >= 10 else "low", notes

    if low_quality_count >= 3 and speech_ratio > 0.15:
        notes.append(f"{low_quality_count} utterance SNR rendah — bicara terbata/ tersendat")
        if analyzable_count == 0:
            return "low", notes

    if analyzable_count >= 2 and confirmed_seconds > 0:
        avg_u = confirmed_seconds / analyzable_count
        if avg_u < 1.2 and speech_ratio > 0.2:
            notes.append("Utterance pendek — gangguan fluensi")
            return "low", notes

    if analyzable_count > 0 and vad_active_seconds >= 3:
        notes.append("Fluensi dinilai dari pola VAD; analisis semantik pada segmen klinis jika Whisper tersedia")
        return "none", notes

    if vad_active_seconds >= 5:
        notes.append("Fluensi terbatas tanpa utterance akustik lengkap")
    return "unknown", notes


def utterance_clinical_flags(u: UtteranceResult) -> list[str]:
    """Flag hanya untuk indikasi kuat — bicara normal tidak ikut direkam."""
    flags: list[str] = []
    dys_flags = utterance_dysarthria_flags(u.features)
    if len(dys_flags) >= 2:
        flags.extend(dys_flags)
        flags.append("disartria")
    elif len(dys_flags) == 1:
        flags.append(dys_flags[0])

    if u.pcm_samples is not None and len(u.pcm_samples) > 0:
        flu = analyze_intra_utterance_fluency(u.pcm_samples)
        if flu["disfluency"] == "high":
            flags.append("disfluensi")
            flags.append("indikasi_disfluensi")
        elif flu["disfluency"] == "medium" and flu["pause_count"] >= 4:
            flags.append("indikasi_disfluensi")

    return flags


@dataclass
class SpeechRhythm:
    """Metrik ritme bicara pada jendela waktu — dasar deteksi disfluensi."""

    span_ms: float
    speech_ms: int
    gap_ms: float
    utterance_count: int
    avg_utterance_ms: float
    fragmentation_per_sec: float
    gap_ratio: float


def speech_rhythm(
    utterances: list[UtteranceResult],
    window_ms: float = 14000,
    min_utterances: int = 3,
    min_span_ms: float = 2500,
) -> SpeechRhythm | None:
    """Ritme bicara pada jendela terakhir.

    Pembeda utama bicara normal vs terbata bukan panjang satu ucapan,
    tapi seberapa sering ucapan terpotong (fragmentasi) dan porsi jeda.
    """
    if not utterances:
        return None

    last = utterances[-1]
    last_end = last.started_at_ms + last.duration_ms
    cutoff = last_end - window_ms
    window = [u for u in utterances if u.started_at_ms >= cutoff]

    if len(window) < min_utterances:
        return None

    span = last_end - window[0].started_at_ms
    if span < min_span_ms:
        return None

    speech_ms = sum(u.duration_ms for u in window)
    gap_ms = max(0.0, span - speech_ms)

    return SpeechRhythm(
        span_ms=span,
        speech_ms=speech_ms,
        gap_ms=gap_ms,
        utterance_count=len(window),
        avg_utterance_ms=speech_ms / len(window),
        fragmentation_per_sec=len(window) / (span / 1000.0),
        gap_ratio=gap_ms / span,
    )


def _rhythm_suggests_stutter(rhythm: SpeechRhythm, window: list[UtteranceResult]) -> bool:
    """Bicara terbata klinis — bukan percakapan cepat dengan frasa panjang."""
    if not window or rhythm.span_ms <= 0:
        return False

    speech_density = rhythm.speech_ms / rhythm.span_ms
    short_frags = sum(1 for u in window if u.duration_ms < 420)
    short_ratio = short_frags / len(window)

    return (
        rhythm.avg_utterance_ms < 480
        and short_ratio >= 0.55
        and rhythm.gap_ratio >= 0.38
        and rhythm.fragmentation_per_sec >= 1.4
        and speech_density < 0.52
        and rhythm.utterance_count >= 6
    )


def live_utterance_alert(
    utterances: list[UtteranceResult],
    current: UtteranceResult,
    *,
    vad_segment_count: int = 0,
) -> dict | None:
    """Alert real-time: fluensi internal + ritme + akustik."""
    flags = utterance_clinical_flags(current)

    # disfluensi internal pada utterance saat ini (a-a-a-aku)
    if current.pcm_samples is not None and len(current.pcm_samples) > 0:
        flu = analyze_intra_utterance_fluency(current.pcm_samples)
        flu_high = flu["disfluency"] == "high" or (
            flu["disfluency"] == "medium" and flu["pause_count"] >= 3
        )
        if flu_high:
            return {
                "severity": "high",
                "reason": (
                    f"Disfluensi berat — {flu['pause_count']} suku kata terputus "
                    f"({flu['pause_rate']}/detik)"
                ),
                "flags": sorted(set(flags + ["indikasi_disfluensi", "disfluensi"])),
            }

    # VAD toggle tinggi vs sedikit utterance = blocking/stuttering (butuh bukti kuat)
    if len(utterances) >= 2 and vad_segment_count >= 8:
        ratio = vad_segment_count / max(len(utterances), 1)
        if ratio >= 4.0 and current.vad_prob_avg >= 0.55:
            return {
                "severity": "medium",
                "reason": "Ucapan tersendat — aktivitas suara sering terputus",
                "flags": sorted(set(flags + ["indikasi_disfluensi", "disfluensi"])),
            }

    # disartria akustik: minimal dua parameter vokal abnormal sekaligus
    dys_count = sum(
        1 for f in flags if f in ("jitter_tinggi", "shimmer_tinggi", "hnr_rendah", "pitch_tidak_stabil")
    )
    if dys_count >= 2:
        return {
            "severity": "medium",
            "reason": "Indikator disartria terdeteksi (jitter/shimmer/HNR abnormal)",
            "flags": sorted(set(flags)),
        }

    rhythm = speech_rhythm(utterances)
    if rhythm is not None:
        last = utterances[-1]
        last_end = last.started_at_ms + last.duration_ms
        cutoff = last_end - rhythm.span_ms
        window = [u for u in utterances if u.started_at_ms >= cutoff]

        # SOS hanya dari ritme jika pola sangat khas stutter (bukan frasa normal)
        if _rhythm_suggests_stutter(rhythm, window):
            return {
                "severity": "high",
                "reason": (
                    f"Pola bicara tersendat — {rhythm.utterance_count} potongan pendek "
                    f"dalam {rhythm.span_ms / 1000:.0f}s"
                ),
                "flags": sorted(set(flags + ["indikasi_disfluensi", "disfluensi"])),
            }

        # frasa cepat normal: potongan cukup panjang → tidak alert
        if rhythm.avg_utterance_ms >= 900:
            return None

        # terbata sedang — catat saja, tanpa SOS
        if (
            rhythm.avg_utterance_ms < 550
            and rhythm.fragmentation_per_sec >= 1.4
            and rhythm.gap_ratio >= 0.5
        ):
            return {
                "severity": "medium",
                "reason": (
                    f"Pola bicara terputus-putus — {rhythm.utterance_count} potongan "
                    f"dalam {rhythm.span_ms / 1000:.0f}s"
                ),
                "flags": sorted(set(flags + ["indikasi_disfluensi"])),
            }

    # kualitas rendah menyeluruh disertai fitur akustik abnormal
    if any(f in flags for f in ("jitter_tinggi", "shimmer_tinggi", "hnr_rendah")):
        low_quality = sum(
            1 for u in utterances[-6:] if u.status == SegmentQuality.LOW_QUALITY and u.vad_prob_avg >= 0.65
        )
        if low_quality >= 5:
            return {
                "severity": "medium",
                "reason": "Ucapan berkualitas rendah dengan fitur akustik abnormal",
                "flags": sorted(set(flags + ["disartria_proxy"])),
            }
    return None


def _flag_utterance(
    u: UtteranceResult,
    dysarthria_risk: str,
    aphasia_risk: str,
) -> list[str]:
    """Hanya flag intrinsik utterance — tidak proxy dari risiko sesi."""
    return utterance_clinical_flags(u)


def _utterance_end_ms(u: UtteranceResult) -> float:
    return u.started_at_ms + u.duration_ms


def _merge_pcm_parts(utts: list[UtteranceResult], sample_rate: int) -> np.ndarray:
    parts: list[np.ndarray] = []
    for i, u in enumerate(utts):
        if i > 0:
            prev = utts[i - 1]
            gap_ms = u.started_at_ms - _utterance_end_ms(prev)
            if gap_ms > 0:
                gap_samples = int(gap_ms / 1000.0 * sample_rate)
                if gap_samples > 0:
                    parts.append(np.zeros(gap_samples, dtype=np.int16))
        if u.pcm_samples is not None and len(u.pcm_samples) > 0:
            parts.append(u.pcm_samples.astype(np.int16))
    if not parts:
        return np.array([], dtype=np.int16)
    return np.concatenate(parts)


def _emit_episode(
    utts: list[UtteranceResult],
    flags: set[str],
    *,
    sample_rate: int,
    max_pcm_bytes: int,
) -> dict | None:
    if not utts:
        return None

    pcm = _merge_pcm_parts(utts, sample_rate)
    if len(pcm) > max_pcm_bytes // 2:
        pcm = pcm[: max_pcm_bytes // 2]

    duration_ms = int(len(pcm) / sample_rate * 1000) if len(pcm) else 0
    start_ms = utts[0].started_at_ms

    snrs = [u.snr_db for u in utts if u.snr_db > -20]
    vads = [u.vad_prob_avg for u in utts]
    jitters = [u.features.jitter * 100 for u in utts if u.features]
    shimmers = [u.features.shimmer * 100 for u in utts if u.features]

    pcm_b64 = None
    if len(pcm) > 0:
        pcm_b64 = base64.b64encode(pcm.tobytes()).decode()

    return {
        "started_at_ms": start_ms,
        "ended_at_ms": start_ms + duration_ms,
        "offset_sec": int(start_ms // 1000),
        "duration_ms": duration_ms,
        "utterance_count": len(utts),
        "flags": sorted(flags),
        "snr_db": round(sum(snrs) / len(snrs), 1) if snrs else 0.0,
        "vad_prob_avg": round(sum(vads) / len(vads), 2) if vads else 0.0,
        "jitter": round(sum(jitters) / len(jitters), 2) if jitters else None,
        "shimmer": round(sum(shimmers) / len(shimmers), 2) if shimmers else None,
        "pcm_base64": pcm_b64,
        "transcript": None,
        "semantic_risk": "unknown",
        "semantic_notes": [],
    }


def _episode_min_duration_ms(utterance_count: int, flags: set[str] | None = None) -> int:
    cfg = speech_settings
    if flags and ({"disfluensi", "indikasi_disfluensi", "disartria"} & flags):
        return 400
    if utterance_count >= 2:
        return 600
    return max(600, cfg.episode_min_ms // 2)


def _build_risk_window_episode(
    utterances: list[UtteranceResult],
    dysarthria_risk: str,
    aphasia_risk: str,
    *,
    sample_rate: int,
    max_pcm_bytes: int,
) -> list[dict]:
    """Fallback episode dari jendela ritme bila risiko sesi terdeteksi tapi flag per-utterance kurang."""
    rhythm = speech_rhythm(utterances)
    if rhythm is None or not utterances:
        return []

    last = utterances[-1]
    last_end = last.started_at_ms + last.duration_ms
    cutoff = last_end - rhythm.span_ms
    window = [u for u in utterances if u.started_at_ms >= cutoff]
    if len(window) < 3:
        return []

    flags: set[str] = set()
    if dysarthria_risk in ("low", "medium", "high"):
        flags.add("disartria_proxy")
    if aphasia_risk in ("low", "medium", "high"):
        flags.add("afasia_proxy")
    flags.add("disfluensi")

    ep = _emit_episode(window, flags, sample_rate=sample_rate, max_pcm_bytes=max_pcm_bytes)
    if ep and ep["duration_ms"] >= 800:
        return [ep]
    return []


def _build_session_recording_episode(
    utterances: list[UtteranceResult],
    peak_alert: dict | None,
    dysarthria_risk: str,
    aphasia_risk: str,
    *,
    sample_rate: int,
    max_pcm_bytes: int,
) -> list[dict]:
    """Gabung semua audio sesi yang ada indikasi — untuk replay setelah SOS."""
    with_pcm = [
        u for u in utterances
        if u.pcm_samples is not None and len(u.pcm_samples) > 0
    ]
    if not with_pcm:
        return []

    flagged = [u for u in with_pcm if utterance_clinical_flags(u)]
    window = flagged if flagged else with_pcm

    speech_ms = sum(u.duration_ms for u in window)
    if speech_ms > 12000:
        window = window[-6:]

    flags: set[str] = set()
    if peak_alert:
        flags.update(peak_alert.get("flags") or [])
    for u in window:
        flags.update(utterance_clinical_flags(u))
    if dysarthria_risk in ("medium", "high"):
        flags.add("indikasi_disartria")
    if aphasia_risk in ("medium", "high"):
        flags.add("indikasi_disfluensi")
    if not flags and peak_alert is None:
        return []

    ep = _emit_episode(window, flags, sample_rate=sample_rate, max_pcm_bytes=max_pcm_bytes)
    if ep and ep["duration_ms"] >= 400:
        return [ep]
    return []


def _build_recent_clinical_episode(
    utterances: list[UtteranceResult],
    dysarthria_risk: str,
    aphasia_risk: str,
    peak_alert: dict | None,
    *,
    sample_rate: int,
    max_pcm_bytes: int,
) -> list[dict]:
    """Episode dari utterance terakhir — untuk SOS live / sesi pendek."""
    with_pcm = [
        u for u in utterances
        if u.pcm_samples is not None and len(u.pcm_samples) > 0
    ]
    if not with_pcm:
        return []

    window = with_pcm[-3:]
    flags: set[str] = set()
    if peak_alert:
        flags.update(peak_alert.get("flags") or [])
    for u in window:
        flags.update(utterance_clinical_flags(u))
    if dysarthria_risk in ("medium", "high"):
        flags.add("indikasi_disartria")
    if aphasia_risk in ("medium", "high"):
        flags.add("indikasi_disfluensi")

    if not flags:
        return []

    ep = _emit_episode(window, flags, sample_rate=sample_rate, max_pcm_bytes=max_pcm_bytes)
    if ep and ep["duration_ms"] >= 400:
        return [ep]
    return []


def _event_center_ms(utterances: list[UtteranceResult], event: dict) -> float | None:
    idx = event.get("utterance_index")
    if idx is not None:
        idx = int(idx)
        if 0 <= idx < len(utterances):
            u = utterances[idx]
            return u.started_at_ms + u.duration_ms / 2
    started = event.get("started_at_ms")
    return float(started) if started is not None else None


def _extract_pcm_window(
    utterances: list[UtteranceResult],
    center_ms: float,
    *,
    sample_rate: int,
    window_ms: int,
) -> np.ndarray:
    """Potong audio kontinu di sekitar titik deteksi (termasuk jeda)."""
    half = window_ms / 2
    win_start = center_ms - half
    win_end = center_ms + half

    slices: list[tuple[float, np.ndarray]] = []
    for u in sorted(utterances, key=lambda x: x.started_at_ms):
        if u.pcm_samples is None or len(u.pcm_samples) == 0:
            continue
        u_start = u.started_at_ms
        u_end = u_start + u.duration_ms
        if u_end <= win_start or u_start >= win_end:
            continue

        pcm = u.pcm_samples.astype(np.int16)
        if u_start < win_start:
            trim = int((win_start - u_start) / 1000 * sample_rate)
            pcm = pcm[min(trim, len(pcm)) :]
            u_start = win_start
        u_end = u_start + len(pcm) / sample_rate * 1000
        if u_end > win_end:
            keep = int((win_end - u_start) / 1000 * sample_rate)
            pcm = pcm[: max(0, keep)]
        if len(pcm) > 0:
            slices.append((u_start, pcm))

    target_samples = int(window_ms / 1000 * sample_rate)
    if not slices:
        return np.zeros(target_samples, dtype=np.int16)

    parts: list[np.ndarray] = []
    cursor = win_start
    for start_ms, pcm in slices:
        gap_ms = start_ms - cursor
        if gap_ms > 1:
            gap_samples = int(gap_ms / 1000 * sample_rate)
            if gap_samples > 0:
                parts.append(np.zeros(gap_samples, dtype=np.int16))
        parts.append(pcm)
        cursor = start_ms + len(pcm) / sample_rate * 1000

    merged = np.concatenate(parts) if parts else np.array([], dtype=np.int16)
    if len(merged) > target_samples:
        excess = len(merged) - target_samples
        start = excess // 2
        merged = merged[start : start + target_samples]
    elif len(merged) < target_samples:
        pad = target_samples - len(merged)
        before = pad // 2
        merged = np.concatenate([
            np.zeros(before, dtype=np.int16),
            merged,
            np.zeros(pad - before, dtype=np.int16),
        ])
    return merged


def _confirm_sos_event(
    utterances: list[UtteranceResult],
    event: dict,
    *,
    sample_rate: int,
    confirm_ms: int,
) -> bool:
    """Validasi 2 detik di sekitar momen SOS — buang false positive."""
    center = _event_center_ms(utterances, event)
    if center is None:
        return False

    pcm = _extract_pcm_window(
        utterances, center, sample_rate=sample_rate, window_ms=confirm_ms,
    )
    min_samples = int(sample_rate * 0.35)
    if len(pcm) < min_samples:
        return False

    alert = event.get("alert") or {}
    reason = str(alert.get("reason") or "")
    flags = alert.get("flags") or []
    disflu = any("disfluensi" in str(f) for f in flags)

    if disflu and "Pola bicara tersendat" not in reason:
        flu = analyze_intra_utterance_fluency(pcm, sample_rate)
        return flu["pause_count"] >= 2 or flu["disfluency"] in ("medium", "high")

    if "Pola bicara tersendat" in reason or "terputus" in reason:
        half = confirm_ms / 2
        win_start = center - half
        win_end = center + half
        in_window = [
            u for u in utterances
            if win_start <= u.started_at_ms <= win_end
        ]
        return len(in_window) >= 3

    # disartria/jitter: cek fitur akustik pada jendela konfirmasi
    if any(f in ("jitter_tinggi", "shimmer_tinggi", "disartria") for f in flags):
        idx = int(event.get("utterance_index", -1))
        if 0 <= idx < len(utterances) and utterances[idx].features:
            f = utterances[idx].features
            if f.jitter > 0.009 or f.shimmer > 0.05 or f.hnr < 14:
                return True
        return False

    return True


def _emit_episode_from_pcm(
    pcm: np.ndarray,
    start_ms: float,
    flags: set[str],
    *,
    sample_rate: int,
    max_pcm_bytes: int,
    utterance_count: int = 1,
    sos_reason: str | None = None,
) -> dict | None:
    if pcm is None or len(pcm) == 0:
        return None

    pcm = pcm.astype(np.int16)
    if len(pcm) > max_pcm_bytes // 2:
        pcm = pcm[: max_pcm_bytes // 2]

    duration_ms = int(len(pcm) / sample_rate * 1000)
    pcm_b64 = base64.b64encode(pcm.tobytes()).decode()

    ep = {
        "started_at_ms": start_ms,
        "ended_at_ms": start_ms + duration_ms,
        "offset_sec": int(start_ms // 1000),
        "duration_ms": duration_ms,
        "utterance_count": utterance_count,
        "flags": sorted(flags),
        "snr_db": 0.0,
        "vad_prob_avg": 0.0,
        "jitter": None,
        "shimmer": None,
        "pcm_base64": pcm_b64,
        "transcript": None,
        "semantic_risk": "unknown",
        "semantic_notes": [],
    }
    if sos_reason:
        ep["sos_reason"] = sos_reason
    return ep


def build_clinical_segments(
    utterances: list[UtteranceResult],
    dysarthria_risk: str,
    aphasia_risk: str,
    *,
    max_segments: int | None = None,
    max_pcm_bytes: int | None = None,
    peak_alert: dict | None = None,
    sos_events: list[dict] | None = None,
) -> list[dict]:
    """Rekaman klinis hanya untuk momen yang memicu SOS (severity high)."""
    cfg = speech_settings
    max_segments = max_segments or cfg.max_clinical_episodes
    max_pcm_bytes = max_pcm_bytes or int(cfg.sample_rate * cfg.episode_max_ms / 1000) * 2
    sample_rate = cfg.sample_rate

    events = list(sos_events or [])
    if not events and peak_alert and peak_alert.get("severity") == "high" and utterances:
        events = [{
            "utterance_index": len(utterances) - 1,
            "started_at_ms": utterances[-1].started_at_ms,
            "alert": peak_alert,
        }]

    if not events:
        return []

    episodes: list[dict] = []
    seen_starts: set[int] = set()
    confirm_ms = cfg.sos_confirm_window_ms
    record_ms = cfg.sos_recording_window_ms
    min_record_ms = record_ms - 200  # toleransi rounding

    for event in events:
        alert = event.get("alert") or {}
        if alert.get("severity") != "high":
            continue

        if not _confirm_sos_event(
            utterances, event, sample_rate=sample_rate, confirm_ms=confirm_ms,
        ):
            continue

        center = _event_center_ms(utterances, event)
        if center is None:
            continue

        start_key = int(center - record_ms / 2)
        if start_key in seen_starts:
            continue
        seen_starts.add(start_key)

        pcm = _extract_pcm_window(
            utterances, center, sample_rate=sample_rate, window_ms=record_ms,
        )
        if len(pcm) < int(sample_rate * min_record_ms / 1000):
            continue

        flags: set[str] = set(alert.get("flags") or [])
        flags.update({"sos", "indikasi_disfluensi"})

        ep = _emit_episode_from_pcm(
            pcm,
            start_key,
            flags,
            sample_rate=sample_rate,
            max_pcm_bytes=max_pcm_bytes,
            sos_reason=alert.get("reason"),
        )
        if ep and ep["duration_ms"] >= min_record_ms:
            episodes.append(ep)

    return episodes[:max_segments]


def enrich_clinical_segments_semantics(
    segments: list[dict],
    *,
    sample_rate: int | None = None,
    max_analyze: int = 3,
) -> list[dict]:
    from app.speech.linguistic import analyze_episode_semantics

    if not segments:
        return segments

    sample_rate = sample_rate or speech_settings.sample_rate

    def _priority(seg: dict) -> tuple[int, int]:
        flags = seg.get("flags") or []
        afasia = any("afasia" in f or "disfluensi" in f for f in flags)
        return (0 if afasia else 1, -(seg.get("duration_ms") or 0))

    for seg in sorted(segments, key=_priority)[:max_analyze]:
        pcm_b64 = seg.get("pcm_base64")
        if not pcm_b64:
            continue
        pcm = np.frombuffer(base64.b64decode(pcm_b64), dtype=np.int16)
        sem = analyze_episode_semantics(pcm, sample_rate)
        seg.update(sem)

    return segments


def apply_semantic_aphasia_risk(
    aphasia_risk: str,
    aphasia_notes: list[str],
    segments: list[dict],
) -> tuple[str, list[str]]:
    notes = list(aphasia_notes)
    risks = [
        s.get("semantic_risk")
        for s in segments
        if s.get("semantic_risk") not in (None, "unknown", "none")
    ]
    if not risks:
        has_whisper = any(s.get("transcript") for s in segments)
        if has_whisper:
            notes = [n for n in notes if "Whisper" not in n and "semantik" not in n.lower()]
            notes.append("Analisis semantik selesai — transkrip dalam batas normal")
        return aphasia_risk, notes

    if "medium" in risks or "high" in risks:
        if aphasia_risk in ("unknown", "none", "low"):
            aphasia_risk = "medium"
        for s in segments:
            for note in s.get("semantic_notes") or []:
                if note not in notes:
                    notes.append(note)
    elif "low" in risks and aphasia_risk in ("unknown", "none"):
        aphasia_risk = "low"

    return aphasia_risk, notes


def _avg_features(features: list[AcousticFeatures]) -> dict[str, float]:
    if not features:
        return {}
    n = len(features)
    return {
        "jitter": sum(f.jitter for f in features) / n,
        "shimmer": sum(f.shimmer for f in features) / n,
        "hnr": sum(f.hnr for f in features) / n,
        "pitch_mean": sum(f.pitch_mean for f in features) / n,
        "pitch_std": sum(f.pitch_std for f in features) / n,
    }
