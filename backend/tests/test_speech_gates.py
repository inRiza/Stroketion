import numpy as np
import pytest

from app.speech.buffer import UtteranceBuffer
from app.speech.gates import EnergyGate
from app.speech.models import AudioFrame


def _frame(samples: np.ndarray, ts: float = 0) -> AudioFrame:
    return AudioFrame(samples=samples, sample_rate=16000, timestamp_ms=ts)


def test_energy_gate_silence():
    gate = EnergyGate(silence_threshold_dbfs=-45.0)
    silence = np.zeros(1600, dtype=np.int16)
    assert gate.passes(_frame(silence)) is False


def test_energy_gate_speech_like():
    gate = EnergyGate(silence_threshold_dbfs=-45.0)
    t = np.linspace(0, 0.1, 1600)
    speech = (np.sin(2 * np.pi * 200 * t) * 8000).astype(np.int16)
    assert gate.passes(_frame(speech)) is True


def test_utterance_buffer_closes_on_silence_gap():
    buf = UtteranceBuffer(silence_gap_ms=500)
    t = np.linspace(0, 0.1, 1600)
    speech = (np.sin(2 * np.pi * 200 * t) * 8000).astype(np.int16)
    silence = np.zeros(1600, dtype=np.int16)

    assert buf.add(_frame(speech, 0), True, 0.8) == (None, 0.0, 0.0)
    assert buf.add(_frame(speech, 100), True, 0.85) == (None, 0.0, 0.0)
    result, started, avg_vad = buf.add(_frame(silence, 700), False, 0.1)
    assert result is not None
    assert len(result) > 0
    assert started == 0.0
    assert avg_vad > 0.8


def test_utterance_buffer_max_duration_flush():
    buf = UtteranceBuffer(max_utterance_ms=300, sample_rate=16000)
    t = np.linspace(0, 0.1, 1600)
    speech = (np.sin(2 * np.pi * 200 * t) * 8000).astype(np.int16)

    result = None
    for i in range(25):
        chunk, _, _ = buf.add(_frame(speech, i * 100), True, 0.85)
        if chunk is not None:
            result = chunk
            break

    assert result is not None
    assert len(result) >= 16000 * 0.25
