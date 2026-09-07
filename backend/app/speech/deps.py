class SpeechMlUnavailableError(RuntimeError):
    def __init__(self, component: str, detail: str):
        self.component = component
        self.detail = detail
        super().__init__(f"Speech ML tidak tersedia ({component}): {detail}")


_warmed = False


def ensure_speech_ml(*, warm: bool = False) -> None:
    global _warmed

    missing: list[str] = []
    for name, module in (
        ("torch", "torch"),
        ("torchaudio", "torchaudio"),
        ("deepfilternet", "df"),
        ("praat-parselmouth", "parselmouth"),
    ):
        try:
            __import__(module)
        except ImportError as exc:
            missing.append(f"{name} ({exc})")

    if missing:
        raise SpeechMlUnavailableError("dependencies", "; ".join(missing))

    if warm and not _warmed:
        from app.speech.denoiser import _load_denoiser
        from app.speech.gates import _load_silero_vad

        _load_silero_vad()
        _load_denoiser()
        _warmed = True
