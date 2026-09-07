"""Deteksi disfluensi internal — fokus pola repetisi suku kata (a-a-a-aku).

Bicara normal cepat dengan banyak frasa punya jeda antar kata, tapi burst
suku kata cenderung panjang. Stuttering: burst sangat pendek (40–100ms)
berulang dengan micro-pause di antaranya.
"""

import numpy as np


def _burst_lengths(active: np.ndarray) -> tuple[list[int], list[int]]:
    """Panjang burst aktif (frame) dan jeda di antar burst (frame)."""
    bursts: list[int] = []
    pauses: list[int] = []
    i = 0
    n = len(active)
    while i < n:
        if not active[i]:
            i += 1
            continue
        j = i
        while j < n and active[j]:
            j += 1
        bursts.append(j - i)
        i = j
        if i >= n:
            break
        j = i
        while j < n and not active[j]:
            j += 1
        if j > i:
            pauses.append(j - i)
        i = j
    return bursts, pauses


def _count_stutter_pauses(bursts: list[int], pauses: list[int]) -> int:
    """Hitung micro-pause khas stutter: di antara dua burst pendek."""
    if len(bursts) < 2 or not pauses:
        return 0

    count = 0
    for idx, pause_len in enumerate(pauses):
        if idx + 1 >= len(bursts):
            break
        before = bursts[idx]
        after = bursts[idx + 1]
        # burst pendek (≤120ms @ 20ms/frame = 6 frame) + jeda 20–100ms
        if before <= 6 and after <= 6 and 1 <= pause_len <= 5:
            count += 1
    return count


def analyze_intra_utterance_fluency(
    pcm: np.ndarray,
    sample_rate: int = 16000,
    *,
    frame_ms: int = 20,
) -> dict:
    frame_samples = max(1, int(sample_rate * frame_ms / 1000))
    if pcm is None or len(pcm) < frame_samples * 8:
        return {"pause_count": 0, "pause_rate": 0.0, "disfluency": "none"}

    samples = pcm.astype(np.float64)
    n_frames = len(samples) // frame_samples
    if n_frames < 8:
        return {"pause_count": 0, "pause_rate": 0.0, "disfluency": "none"}

    rms = np.array([
        float(np.sqrt(np.mean(samples[i * frame_samples : (i + 1) * frame_samples] ** 2)))
        for i in range(n_frames)
    ])
    peak = float(np.percentile(rms, 85))
    if peak < 1e-6:
        return {"pause_count": 0, "pause_rate": 0.0, "disfluency": "none"}

    # ambang adaptif — tangkap stutter lembut tanpa jeda antar kata normal
    active = rms > peak * 0.30
    bursts, pauses = _burst_lengths(active)
    stutter_pauses = _count_stutter_pauses(bursts, pauses)

    # pass kedua lebih sensitif bila belum ada pola jelas
    if stutter_pauses < 3:
        soft_active = rms > peak * 0.22
        soft_bursts, soft_pauses = _burst_lengths(soft_active)
        soft_count = _count_stutter_pauses(soft_bursts, soft_pauses)
        if soft_count > stutter_pauses:
            stutter_pauses = soft_count

    duration_sec = len(samples) / sample_rate
    pause_rate = stutter_pauses / max(duration_sec, 0.1)

    disfluency = "none"
    # pola repetisi burst pendek — ambang sedikit lebih sensitif dari sebelumnya
    if stutter_pauses >= 4 or (stutter_pauses >= 3 and pause_rate >= 2.0):
        disfluency = "high"
    elif stutter_pauses >= 3 or pause_rate >= 1.5:
        disfluency = "medium"
    elif stutter_pauses >= 2:
        disfluency = "low"

    return {
        "pause_count": stutter_pauses,
        "pause_rate": round(pause_rate, 2),
        "disfluency": disfluency,
    }


def session_disfluency_summary(utterances: list) -> dict:
    """Ringkas fluensi internal seluruh sesi."""
    levels: list[str] = []
    total_pauses = 0
    for u in utterances:
        if u.pcm_samples is None or len(u.pcm_samples) == 0:
            continue
        flu = analyze_intra_utterance_fluency(u.pcm_samples)
        levels.append(flu["disfluency"])
        total_pauses += flu["pause_count"]

    high = sum(1 for x in levels if x == "high")
    medium = sum(1 for x in levels if x == "medium")

    if high >= 2 or (high >= 1 and total_pauses >= 8):
        session_level = "high"
    elif high >= 1 or medium >= 2:
        session_level = "medium"
    elif medium >= 1:
        session_level = "low"
    else:
        session_level = "none"

    return {
        "session_disfluency": session_level,
        "high_utterances": high,
        "medium_utterances": medium,
        "total_micro_pauses": total_pauses,
    }
