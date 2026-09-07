import numpy as np

from app.speech.pipeline import SpeechPipeline, SpeechStreamState


def test_noise_reference_avoids_numpy_or_truthiness():
    pipeline = SpeechPipeline()
    state = SpeechStreamState("test")
    utterance = np.array([100, 200, 300, 400], dtype=np.int16)
    state._noise_tail = np.array([1, 2, 3], dtype=np.int16)

    ref = pipeline._noise_reference(utterance, state)
    assert ref is state._noise_tail

    state._noise_tail = None
    ref = pipeline._noise_reference(utterance, state)
    assert len(ref) == 1
