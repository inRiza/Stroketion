from contextlib import asynccontextmanager
import asyncio
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.database import Base, engine
from app.models import domain  # noqa: F401

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    try:
        from app.speech.deps import SpeechMlUnavailableError, ensure_speech_ml

        logger.info("Preloading speech ML models...")
        await asyncio.to_thread(ensure_speech_ml, warm=True)
        logger.info("Speech ML models ready")
    except SpeechMlUnavailableError as exc:
        logger.warning("Speech ML not available at startup: %s", exc)
    except Exception as exc:
        logger.warning("Speech ML preload failed: %s", exc)

    yield


app = FastAPI(
    title=settings.APP_NAME,
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.get("/health")
async def health_check():
    return {"status": "ok", "service": settings.APP_NAME}
