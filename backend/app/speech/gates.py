import numpy as np

from app.speech.config import speech_settings
from app.speech.deps import SpeechMlUnavailableError
from app.speech.models import AudioFrame


class EnergyGate:
    def __init__(self, silence_threshold_dbfs: float | None = None):
        self.threshold = silence_threshold_dbfs or speech_settings.energy_threshold_dbfs

    def dbfs(self, samples: np.ndarray) -> float:
        rms = np.sqrt(np.mean(samples.astype(np.float64) ** 2))
        return float(20 * np.log10(rms + 1e-10))

    def passes(self, frame: AudioFrame) -> bool:
        return self.dbfs(frame.samples) > self.threshold


_vad_model = None
_vad_utils = None


def _load_silero_vad():
    global _vad_model, _vad_utils
    if _vad_model is not None:
        return _vad_model, _vad_utils

    try:
        import torch

        model, utils = torch.hub.load(
            repo_or_dir="snakers4/silero-vad",
            model="silero_vad",
            force_reload=False,
            trust_repo=True,
        )
    except Exception as exc:
        raise SpeechMlUnavailableError("silero-vad", str(exc)) from exc

    _vad_model = model
    _vad_utils = utils
    return model, utils


class VADGate:
    def __init__(self, speech_prob_threshold: float | None = None):
        self.threshold = speech_prob_threshold or speech_settings.vad_prob_threshold
        self._model = None

    def _ensure_loaded(self) -> None:
        if self._model is not None:
            return
        model, _utils = _load_silero_vad()
        self._model = model

    def probability(self, frame: AudioFrame) -> float:
        samples = frame.samples.astype(np.float32)
        if samples.size == 0:
            return 0.0
        if np.max(np.abs(samples)) > 1.0:
            samples = samples / 32768.0

        # Silero VAD at 16 kHz only accepts 512, 1024, or 1536 samples per call.
        if samples.size < 512:
            return 0.0
        if samples.size not in (512, 1024, 1536):
            samples = samples[-512:]

        self._ensure_loaded()
        import torch

        tensor = torch.from_numpy(samples)
        if frame.sample_rate != 16000:
            import torchaudio.functional as F

            tensor = F.resample(tensor, frame.sample_rate, 16000)
        with torch.no_grad():
            prob = self._model(tensor, 16000).item()
        return float(prob)

    def is_speech(self, frame: AudioFrame) -> bool:
        return self.probability(frame) > self.threshold
