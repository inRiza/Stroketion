import numpy as np

from app.speech.config import speech_settings
from app.speech.models import SegmentQuality


class QualityGate:
    def __init__(self, min_snr_db: float | None = None):
        self.min_snr_db = min_snr_db or speech_settings.min_snr_db

    def evaluate(
        self,
        denoised: np.ndarray,
        noise_ref: np.ndarray,
    ) -> tuple[SegmentQuality, float]:
        p_signal = float(np.mean(denoised.astype(np.float64) ** 2))
        p_noise = float(np.mean(noise_ref.astype(np.float64) ** 2)) + 1e-10
        snr_db = 10 * np.log10(p_signal / p_noise)

        if snr_db < self.min_snr_db:
            return SegmentQuality.LOW_QUALITY, float(snr_db)
        if snr_db >= 15:
            return SegmentQuality.ANALYZABLE, float(snr_db)
        return SegmentQuality.ANALYZABLE, float(snr_db)
