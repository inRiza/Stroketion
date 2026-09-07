import re
import tempfile
from pathlib import Path

import numpy as np

_whisper_model = None

# Kamus kata umum Bahasa Indonesia (stroke-relevant + daily speech)
_COMMON_ID_WORDS = frozenset({
    "saya", "aku", "kamu", "anda", "dia", "kita", "kami", "mereka", "ini", "itu", "disini",
    "sana", "sini", "mau", "ingin", "bisa", "tidak", "tak", "belum", "sudah", "ada", "gak",
    "nggak", "apa", "siapa", "dimana", "kapan", "kenapa", "bagaimana", "tolong", "bantu",
    "minum", "makan", "air", "sakit", "kepala", "pusing", "lemas", "baik", "ya", "iya",
    "oh", "dan", "atau", "tapi", "juga", "sangat", "sedikit", "banyak", "hari", "pagi",
    "malam", "rumah", "jalan", "dokter", "obat", "tangan", "kaki", "mata", "mulut", "suara",
    "bicara", "kata", "nama", "enak", "lapar", "haus", "tidur", "bangun", "duduk", "berdiri",
    "jalan", "lari", "mobil", "motor", "keluarga", "anak", "ibu", "bapak", "ayah", "suami",
    "istri", "kakak", "adik", "teman", "pergi", "pulang", "datang", "sini", "sana", "lagi",
    "sudah", "masih", "punya", "minta", "kasih", "terima", "kasih", "makasih", "terima kasih",
    "halo", "hai", "selamat", "pagi", "siang", "sore", "malam", "dingin", "panas", "hujan",
    "badan", "perut", "dada", "leher", "punggung", "lutut", "siku", "jari", "rambut", "wajah",
    "luka", "demam", "batuk", "pilek", "mual", "muntah", "pusing", "pingsan", "jatuh", "terjatuh",
    "rumah sakit", "ambulans", "darurat", "telepon", "hp", "nomor", "alamat", "rumah", "kamar",
    "mandi", "kamar mandi", "dapur", "meja", "kursi", "pintu", "jendela", "baju", "celana",
    "sendiri", "sendirian", "sama", "dengan", "untuk", "dari", "ke", "di", "pada", "yang",
    "adalah", "akan", "sudah", "pernah", "selalu", "kadang", "sering", "jarang", "tidak pernah",
    "enam", "tujuh", "delapan", "sembilan", "sepuluh", "satu", "dua", "tiga", "empat", "lima",
    "besok", "kemarin", "hari ini", "sekarang", "nanti", "tadi", "baru", "lama", "cepat", "lambat",
})


def whisper_available() -> bool:
    try:
        import whisper  # noqa: F401
        return True
    except ImportError:
        return False


_WHISPER_PROMPT = (
    "Transkripsi percakapan bahasa Indonesia. "
    "Ucapan mungkin tidak sempurna karena kondisi medis. "
    "Tulis kata-kata yang diucapkan apa adanya."
)


def _load_whisper():
    global _whisper_model
    if _whisper_model is None:
        import whisper

        # small: jauh lebih akurat untuk Indonesia vs tiny, latency ~3-5s/episode
        _whisper_model = whisper.load_model("small")
    return _whisper_model


def _pcm_to_float32(pcm: np.ndarray) -> np.ndarray:
    samples = pcm.astype(np.float32)
    if np.max(np.abs(samples)) > 1.0:
        samples = samples / 32768.0
    return samples


def transcribe_episode(pcm: np.ndarray, sample_rate: int = 16000) -> str | None:
    if not whisper_available() or len(pcm) < sample_rate // 5:
        return None

    import soundfile as sf

    audio = _pcm_to_float32(pcm)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = Path(tmp.name)
    try:
        sf.write(str(path), audio, sample_rate)
        model = _load_whisper()
        result = model.transcribe(
            str(path),
            language="id",
            fp16=False,
            initial_prompt=_WHISPER_PROMPT,
            temperature=0.0,
            best_of=1,
            beam_size=5,
        )
        text = (result.get("text") or "").strip()
        # abaikan placeholder artefak Whisper [Musik], [Tepuk tangan], dll.
        if text.startswith("[") and text.endswith("]"):
            return None
        return text or None
    finally:
        path.unlink(missing_ok=True)


def assess_transcript_aphasia(text: str) -> tuple[str, list[str]]:
    """Semantic proxy from transcript — not a diagnosis."""
    notes: list[str] = []
    tokens = [re.sub(r"[^\w]", "", w.lower()) for w in text.split()]
    tokens = [t for t in tokens if t]

    if not tokens:
        return "medium", ["Transkrip kosong — ucapan tidak terbentuk jelas (indikator afasia)"]

    if len(tokens) == 1 and len(tokens[0]) <= 2:
        return "medium", ["Hanya vocalisasi singkat tanpa kata bermakna"]

    unique_ratio = len(set(tokens)) / len(tokens)
    if len(tokens) >= 4 and unique_ratio < 0.35:
        notes.append("Banyak repetisi kata — disfluensi/ perseverasi")
        return "low", notes

    known = sum(1 for t in tokens if t in _COMMON_ID_WORDS)
    known_ratio = known / len(tokens)
    if len(tokens) >= 3 and known_ratio < 0.3:
        notes.append(
            f"Kosakata tidak dikenali ({known}/{len(tokens)} kata umum) — indikator afasia semantik"
        )
        return "medium", notes

    if len(tokens) >= 5 and known_ratio < 0.45:
        notes.append("Struktur kosakata lemah — perlu evaluasi afasia lebih lanjut")
        return "low", notes

    notes.append("Transkrip mengandung kata bermakna")
    return "none", notes


def analyze_episode_semantics(
    pcm: np.ndarray,
    sample_rate: int = 16000,
) -> dict:
    transcript = transcribe_episode(pcm, sample_rate)
    if not transcript:
        return {
            "transcript": None,
            "semantic_risk": "unknown",
            "semantic_notes": ["Modul ASR (Whisper) belum terpasang — analisis semantik afasia belum aktif"],
        }

    risk, notes = assess_transcript_aphasia(transcript)
    return {
        "transcript": transcript,
        "semantic_risk": risk,
        "semantic_notes": notes,
    }
