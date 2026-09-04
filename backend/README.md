# Hology Backend

FastAPI backend for the AI-powered stroke behaviour monitoring system.

## Stack

- Python 3.12+
- FastAPI
- PostgreSQL
- Redis
- [uv](https://docs.astral.sh/uv/) for dependency management

## Services (skeleton)

- Authentication
- User management
- Caregiver management
- Personal baseline
- Behaviour history
- Event storage
- Risk events
- Data synchronization
- Notification management

## Setup

```bash
# install dependencies
uv sync

# copy env
cp .env.example .env

# start postgres + redis
docker compose up -d

# run dev server
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API docs: http://localhost:8000/docs

## Project structure

```
app/
├── main.py              # FastAPI entrypoint
├── core/                # config, database, redis
├── api/v1/              # route handlers
├── models/              # SQLAlchemy models
├── schemas/             # Pydantic schemas
└── services/            # business logic
```
