import numpy as np

from app.speech.deps import SpeechMlUnavailableError

_denoiser_model = None
_denoiser_state = None


def _load_denoiser():
    global _denoiser_model, _denoiser_state
    if _denoiser_model is not None and _denoiser_state is not None:
        return _denoiser_model, _denoiser_state

    try:
        from df.enhance import init_df

        model, df_state, _suffix = init_df()
    except Exception as exc:
        raise SpeechMlUnavailableError("deepfilternet", str(exc)) from exc

    _denoiser_model = model
    _denoiser_state = df_state
    return model, df_state


class Denoiser:
    def enhance(self, utterance: np.ndarray, sample_rate: int = 16000) -> np.ndarray:
        model, df_state = _load_denoiser()

        try:
            import torch
            from df.enhance import enhance

            audio = utterance.astype(np.float32)
            if np.max(np.abs(audio)) > 1.0:
                audio = audio / 32768.0
            tensor = torch.from_numpy(audio).unsqueeze(0)
            enhanced = enhance(model, df_state, tensor, pad=True)
            return enhanced.squeeze(0).numpy()
        except Exception as exc:
            raise SpeechMlUnavailableError("deepfilternet", str(exc)) from exc
