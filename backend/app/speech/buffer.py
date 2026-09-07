import numpy as np

from app.speech.config import speech_settings
from app.speech.models import AudioFrame


class UtteranceBuffer:
    def __init__(
        self,
        silence_gap_ms: int | None = None,
        max_utterance_ms: int | None = None,
        sample_rate: int | None = None,
    ):
        self.silence_gap_ms = silence_gap_ms or speech_settings.utterance_silence_gap_ms
        self.sample_rate = sample_rate or speech_settings.sample_rate
        max_ms = max_utterance_ms or speech_settings.utterance_max_ms
        self._max_samples = int(self.sample_rate * max_ms / 1000)
        self._frames: list[AudioFrame] = []
        self._last_speech_ts: float | None = None
        self._vad_probs: list[float] = []
        self._started_at_ms: float | None = None

    def add(
        self,
        frame: AudioFrame,
        is_speech: bool,
        vad_prob: float = 0.0,
    ) -> tuple[np.ndarray | None, float, float]:
        if is_speech:
            if not self._frames:
                self._started_at_ms = frame.timestamp_ms
            self._frames.append(frame)
            self._vad_probs.append(vad_prob)
            self._last_speech_ts = frame.timestamp_ms
            total_samples = sum(len(f.samples) for f in self._frames)
            if total_samples >= self._max_samples:
                return self._emit()
            return None, 0.0, 0.0

        if self._frames and self._last_speech_ts is not None:
            gap_ms = frame.timestamp_ms - self._last_speech_ts
            if gap_ms >= self.silence_gap_ms:
                return self._emit()
        return None, 0.0, 0.0

    def flush(self) -> tuple[np.ndarray | None, float, float]:
        if not self._frames:
            return None, 0.0, 0.0
        return self._emit()

    def _emit(self) -> tuple[np.ndarray | None, float, float]:
        utterance = np.concatenate([f.samples for f in self._frames])
        started = self._started_at_ms or 0.0
        avg_vad = sum(self._vad_probs) / len(self._vad_probs) if self._vad_probs else 0.0
        self._frames.clear()
        self._vad_probs.clear()
        self._last_speech_ts = None
        self._started_at_ms = None
        return utterance, started, avg_vad
