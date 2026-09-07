from app.core.config import settings


class SpeechSettings:
    energy_threshold_dbfs: float = -45.0
    vad_prob_threshold: float = 0.55
    utterance_silence_gap_ms: int = 320
    utterance_max_ms: int = 6000
    min_snr_db: float = 0.0
    min_utterance_ms: int = 250
    episode_gap_ms: int = 2000
    episode_max_ms: int = 15000
    episode_min_ms: int = 1200
    max_clinical_episodes: int = 5
    sos_confirm_window_ms: int = 2000
    sos_recording_window_ms: int = 5000
    sample_rate: int = 16000
    model_cache_dir: str = ".speech_models"


speech_settings = SpeechSettings()

if hasattr(settings, "SPEECH_ENERGY_DBFS"):
    speech_settings.energy_threshold_dbfs = float(settings.SPEECH_ENERGY_DBFS)
if hasattr(settings, "SPEECH_VAD_THRESHOLD"):
    speech_settings.vad_prob_threshold = float(settings.SPEECH_VAD_THRESHOLD)
