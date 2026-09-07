import numpy as np

from app.speech.acoustic import AcousticExtractor
from app.speech.baseline import compute_speech_score, deviation_score
from app.speech.buffer import UtteranceBuffer
from app.speech.config import speech_settings
from app.speech.denoiser import Denoiser
from app.speech.gates import EnergyGate, VADGate
from app.speech.models import (
    AudioFrame,
    LiveFrameResult,
    SegmentQuality,
    SpeechSummary,
    UtteranceResult,
)
from app.speech.quality import QualityGate


class SpeechStreamState:
    def __init__(self, monitoring_session_id: str, sample_rate: int = 16000):
        self.monitoring_session_id = monitoring_session_id
        self.sample_rate = sample_rate
        self.utterances: list[UtteranceResult] = []
        self.last_live: LiveFrameResult | None = None
        self.speech_active = False
        self.vad_active_ms: float = 0.0
        self.vad_segment_count: int = 0
        self.noise_floor_power: float = 1e-8
        self._in_speech: bool = False
        self._noise_tail: np.ndarray | None = None
        self.peak_clinical_alert: dict | None = None
        self.sos_events: list[dict] = []


class SpeechPipeline:
    def __init__(
        self,
        baseline: dict | None = None,
        energy_gate: EnergyGate | None = None,
        vad_gate: VADGate | None = None,
        utterance_buffer: UtteranceBuffer | None = None,
        denoiser: Denoiser | None = None,
        quality_gate: QualityGate | None = None,
        acoustic_extractor: AcousticExtractor | None = None,
    ):
        self.baseline = baseline
        self.energy_gate = energy_gate or EnergyGate()
        self.vad_gate = vad_gate or VADGate()
        self.buffer = utterance_buffer or UtteranceBuffer()
        self.denoiser = denoiser or Denoiser()
        self.quality_gate = quality_gate or QualityGate()
        self.acoustic_extractor = acoustic_extractor or AcousticExtractor()

    def process_frame(
        self,
        state: SpeechStreamState,
        samples: np.ndarray,
        timestamp_ms: float,
    ) -> LiveFrameResult:
        frame = AudioFrame(samples=samples, sample_rate=state.sample_rate, timestamp_ms=timestamp_ms)

        if not self.energy_gate.passes(frame):
            rms = np.sqrt(np.mean(samples.astype(np.float64) ** 2))
            power = float(rms**2)
            if power > 0:
                state.noise_floor_power = 0.85 * state.noise_floor_power + 0.15 * power
            state.speech_active = False
            if state._in_speech:
                state._in_speech = False
            result = LiveFrameResult(
                speech_active=False,
                energy_dbfs=self.energy_gate.dbfs(samples),
                vad_prob=0.0,
            )
            state.last_live = result
            return result

        vad_prob = self.vad_gate.probability(frame)
        is_speech = vad_prob > self.vad_gate.threshold
        state.speech_active = is_speech
        frame_ms = len(samples) / state.sample_rate * 1000.0

        if is_speech:
            if not state._in_speech:
                state.vad_segment_count += 1
                state._in_speech = True
            state.vad_active_ms += frame_ms
        elif state._in_speech:
            state._in_speech = False

        utterance_raw, started_ms, avg_vad = self.buffer.add(frame, is_speech, vad_prob)
        utterance_result = None

        if utterance_raw is not None and len(utterance_raw) > 0:
            utterance_result = self._process_utterance(
                utterance_raw,
                state.sample_rate,
                started_ms,
                avg_vad,
                state,
            )
            state.utterances.append(utterance_result)
        elif not is_speech and len(samples) > 0:
            tail_len = min(len(samples), state.sample_rate // 5)
            state._noise_tail = samples[-tail_len:].copy()

        result = LiveFrameResult(
            speech_active=is_speech,
            energy_dbfs=self.energy_gate.dbfs(samples),
            vad_prob=vad_prob,
            utterance=utterance_result,
        )
        if utterance_result is not None:
            from app.speech.clinical import live_utterance_alert

            result.clinical_alert = live_utterance_alert(
                state.utterances,
                utterance_result,
                vad_segment_count=state.vad_segment_count,
            )
            if result.clinical_alert is not None:
                from app.speech.clinical import track_peak_clinical_alert

                track_peak_clinical_alert(state, result.clinical_alert)
                if result.clinical_alert.get("severity") == "high":
                    state.sos_events.append({
                        "utterance_index": len(state.utterances) - 1,
                        "started_at_ms": utterance_result.started_at_ms,
                        "alert": dict(result.clinical_alert),
                    })
        state.last_live = result
        return result

    def _estimate_snr(
        self,
        utterance: np.ndarray,
        state: SpeechStreamState,
    ) -> float:
        p_signal = float(np.mean(utterance.astype(np.float64) ** 2))
        if state._noise_tail is not None and len(state._noise_tail) > 0:
            p_noise = float(np.mean(state._noise_tail.astype(np.float64) ** 2))
        else:
            p_noise = state.noise_floor_power
        p_noise = max(p_noise, state.noise_floor_power, 1e-10)
        return float(10 * np.log10((p_signal + 1e-10) / p_noise))

    def _process_utterance(
        self,
        utterance: np.ndarray,
        sample_rate: int,
        started_ms: float,
        avg_vad: float,
        state: SpeechStreamState,
    ) -> UtteranceResult:
        duration_ms = int(len(utterance) / sample_rate * 1000)
        if duration_ms < speech_settings.min_utterance_ms:
            return UtteranceResult(
                status=SegmentQuality.LOW_QUALITY,
                duration_ms=duration_ms,
                snr_db=0.0,
                vad_prob_avg=avg_vad,
                started_at_ms=started_ms,
                pcm_samples=utterance.copy(),
            )

        snr_db = self._estimate_snr(utterance, state)
        denoised = self.denoiser.enhance(utterance, sample_rate)

        features = None
        dev = None
        try:
            features = self.acoustic_extractor.extract(denoised, sample_rate)
            dev = deviation_score(features, self.baseline)
        except Exception:
            features = None
            dev = None

        noise_ref = self._noise_reference(utterance, state)
        quality, _ = self.quality_gate.evaluate(utterance, noise_ref)
        is_analyzable = quality == SegmentQuality.ANALYZABLE and features is not None

        if not is_analyzable and features is not None and avg_vad >= 0.5:
            is_analyzable = True

        status = SegmentQuality.ANALYZABLE if is_analyzable else SegmentQuality.LOW_QUALITY

        return UtteranceResult(
            status=status,
            duration_ms=duration_ms,
            snr_db=snr_db,
            vad_prob_avg=avg_vad,
            features=features,
            deviation_score=dev,
            started_at_ms=started_ms,
            pcm_samples=utterance.copy(),
        )

    def _noise_reference(self, utterance: np.ndarray, state: SpeechStreamState) -> np.ndarray:
        if state._noise_tail is not None and len(state._noise_tail) > 0:
            return state._noise_tail
        return utterance[: max(1, len(utterance) // 10)]

    def finalize(self, state: SpeechStreamState, duration_seconds: int) -> SpeechSummary:
        from app.speech.clinical import (
            apply_semantic_aphasia_risk,
            assess_aphasia_proxy,
            assess_dysarthria,
            build_clinical_segments,
            enrich_clinical_segments_semantics,
            finalize_clinical_risks,
        )

        utterance_raw, started_ms, avg_vad = self.buffer.flush()
        if utterance_raw is not None and len(utterance_raw) > 0:
            result = self._process_utterance(
                utterance_raw,
                state.sample_rate,
                started_ms,
                avg_vad,
                state,
            )
            state.utterances.append(result)

        analyzable = [u for u in state.utterances if u.status == SegmentQuality.ANALYZABLE]
        low_quality = [u for u in state.utterances if u.status == SegmentQuality.LOW_QUALITY]
        with_features = [u for u in state.utterances if u.features is not None]

        confirmed_ms = sum(u.duration_ms for u in analyzable)
        confirmed_seconds = confirmed_ms // 1000
        vad_active_seconds = int(state.vad_active_ms // 1000)
        total_utterances = len(state.utterances)

        snrs = [u.snr_db for u in state.utterances if u.snr_db > -20]
        avg_snr = sum(snrs) / len(snrs) if snrs else 0.0

        deviations = [u.deviation_score for u in with_features if u.deviation_score is not None]
        avg_deviation = sum(deviations) / len(deviations) if deviations else None

        feature_list = [u.features for u in with_features if u.features is not None]
        avg_jitter = avg_shimmer = avg_hnr = avg_pitch_std = None
        if feature_list:
            avg_jitter = sum(f.jitter for f in feature_list) / len(feature_list)
            avg_shimmer = sum(f.shimmer for f in feature_list) / len(feature_list)
            avg_hnr = sum(f.hnr for f in feature_list) / len(feature_list)
            avg_pitch_std = sum(f.pitch_std for f in feature_list) / len(feature_list)

        has_baseline = self.baseline is not None and "vector_mean" in (self.baseline or {})
        dys_risk, dys_notes = assess_dysarthria(
            state.utterances,
            avg_deviation,
            has_baseline,
            low_quality_count=len(low_quality),
            vad_segment_count=state.vad_segment_count,
            vad_active_seconds=vad_active_seconds,
        )
        aph_risk, aph_notes = assess_aphasia_proxy(
            vad_active_seconds,
            confirmed_seconds,
            len(analyzable),
            total_utterances,
            len(low_quality),
            state.vad_segment_count,
            duration_seconds,
            state.utterances,
        )
        dys_risk, dys_notes, aph_risk, aph_notes = finalize_clinical_risks(
            state.utterances,
            dys_risk,
            dys_notes,
            aph_risk,
            aph_notes,
            peak_alert=state.peak_clinical_alert,
        )
        clinical_segments = build_clinical_segments(
            state.utterances,
            dys_risk,
            aph_risk,
            peak_alert=state.peak_clinical_alert,
            sos_events=state.sos_events,
        )
        clinical_segments = enrich_clinical_segments_semantics(
            clinical_segments,
            max_analyze=0,
        )
        aph_risk, aph_notes = apply_semantic_aphasia_risk(aph_risk, aph_notes, clinical_segments)
        clinical_notes = dys_notes + aph_notes

        speech_score = compute_speech_score(
            confirmed_seconds,
            duration_seconds,
            avg_deviation,
            vad_active_seconds=vad_active_seconds,
            dysarthria_risk=dys_risk,
            aphasia_risk=aph_risk,
            clinical_segment_count=len(clinical_segments),
        )

        return SpeechSummary(
            confirmed_seconds=confirmed_seconds,
            vad_active_seconds=vad_active_seconds,
            speech_score=speech_score,
            utterance_count=len(analyzable),
            low_quality_count=len(low_quality),
            avg_snr_db=avg_snr,
            avg_deviation=avg_deviation,
            avg_jitter=avg_jitter,
            avg_shimmer=avg_shimmer,
            avg_hnr=avg_hnr,
            avg_pitch_std=avg_pitch_std,
            dysarthria_risk=dys_risk,
            aphasia_risk=aph_risk,
            clinical_notes=clinical_notes,
            clinical_segments=clinical_segments,
            peak_clinical_alert=state.peak_clinical_alert,
            utterances=state.utterances,
        )
