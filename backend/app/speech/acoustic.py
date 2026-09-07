import numpy as np

from app.speech.deps import SpeechMlUnavailableError
from app.speech.models import AcousticFeatures


class AcousticExtractor:
    def extract(self, audio: np.ndarray, sample_rate: int = 16000) -> AcousticFeatures:
        duration_sec = len(audio) / sample_rate if sample_rate else 0.0
        if len(audio) < sample_rate * 0.2:
            return AcousticFeatures(duration_sec=duration_sec)

        try:
            import parselmouth
            from parselmouth.praat import call

            samples = audio.astype(np.float64)
            if np.max(np.abs(samples)) > 1.0:
                samples = samples / 32768.0

            snd = parselmouth.Sound(samples, sampling_frequency=sample_rate)
            pitch = snd.to_pitch()
            point_process = call(snd, "To PointProcess (periodic, cc)", 75, 500)
            jitter = call(point_process, "Get jitter (local)", 0, 0, 0.0001, 0.02, 1.3)
            shimmer = call([snd, point_process], "Get shimmer (local)", 0, 0, 0.0001, 0.02, 1.3, 1.6)
            hnr = call(snd, "To Harmonicity (cc)", 0.01, 75, 0.1, 1.0)
            hnr_mean = call(hnr, "Get mean", 0, 0)

            pitch_values = pitch.selected_array["frequency"]
            pitch_values = pitch_values[pitch_values > 0]

            return AcousticFeatures(
                jitter=float(jitter) if jitter else 0.0,
                shimmer=float(shimmer) if shimmer else 0.0,
                hnr=float(hnr_mean) if hnr_mean else 0.0,
                pitch_mean=float(np.mean(pitch_values)) if len(pitch_values) else 0.0,
                pitch_std=float(np.std(pitch_values)) if len(pitch_values) else 0.0,
                duration_sec=duration_sec,
            )
        except SpeechMlUnavailableError:
            raise
        except Exception as exc:
            raise SpeechMlUnavailableError("parselmouth", str(exc)) from exc
