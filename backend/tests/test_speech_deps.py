import pytest

from app.speech.deps import SpeechMlUnavailableError, ensure_speech_ml


def test_ensure_speech_ml_raises_when_torch_missing(monkeypatch):
    import builtins

    real_import = builtins.__import__

    def fake_import(name, *args, **kwargs):
        if name == "torch":
            raise ImportError("no torch")
        return real_import(name, *args, **kwargs)

    monkeypatch.setattr(builtins, "__import__", fake_import)

    with pytest.raises(SpeechMlUnavailableError) as exc:
        ensure_speech_ml()

    assert "torch" in str(exc.value)
