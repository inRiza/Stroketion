# Stroketion Backend

FastAPI backend for stroke behaviour monitoring: sessions, links, baselines, and real-time speech analysis.

## Stack

- Python 3.11+
- FastAPI + Uvicorn
- SQLAlchemy (async), SQLite or PostgreSQL
- Redis (speech stream state)
- [uv](https://docs.astral.sh/uv/) for dependencies

Optional ML stack (speech): Silero VAD, DeepFilterNet, Parselmouth, Whisper.

## Setup

```bash
uv sync
cp .env.example .env
docker compose up -d          # postgres + redis (optional for local dev)
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Default dev DB: SQLite (`hology.db`). Set `DATABASE_URL` in `.env` for PostgreSQL.

API docs: http://localhost:8000/docs

## API modules

| Prefix | Purpose |
|--------|---------|
| `/api/v1/auth` | Register, login, JWT |
| `/api/v1/sessions` | Upload session, list mine, caregiver patient sessions |
| `/api/v1/links` | QR link request, approve/reject |
| `/api/v1/baselines` | Motion and speech baseline calibration |
| `/api/v1/behaviour` | Status and history per patient |
| `/api/v1/notifications` | SOS and activity feed |
| `/api/v1/speech/stream` | WebSocket PCM 16 kHz pipeline |

## Speech pipeline

```text
PCM frame -> EnergyGate -> VAD -> UtteranceBuffer -> Denoiser -> SNR gate
         -> Acoustic features -> Fluency -> Clinical alerts -> Session summary
```

Key thresholds (`app/speech/config.py`):

| Parameter | Value |
|-----------|-------|
| Energy gate | -45 dBFS |
| VAD probability | 0.55 |
| Utterance silence gap | 320 ms |
| SOS confirm window | 2000 ms |
| Clinical clip length | 5000 ms |

Scoring helpers live in `app/speech/baseline.py` and mirror mobile session weights.

## Project structure

```
app/
├── main.py
├── core/           config, database, security
├── api/v1/         route handlers
├── models/         SQLAlchemy domain
├── schemas/        Pydantic request/response
├── services/       business logic
└── speech/         analysis pipeline modules
tests/              pytest (auth, sessions, speech, sos)
```

## Tests

```bash
uv run pytest -q
uv run pytest tests/test_speech_clinical.py -q   # speech subset
```

## Environment

See `.env.example` for `APP_NAME`, `DATABASE_URL`, `REDIS_URL`, and JWT settings. Never commit `.env`.
