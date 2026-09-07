import os

os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///:memory:"

import pytest

from app.core.database import Base, engine


@pytest.fixture(autouse=True)
async def fresh_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield
