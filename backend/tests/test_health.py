from collections.abc import Sequence

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client() -> AsyncClient:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "path",
    [
        "/api/v1/users/me",
        "/api/v1/caregivers/",
        "/api/v1/baselines/user-1",
        "/api/v1/behaviour/user-1/status",
        "/api/v1/events/",
        "/api/v1/risk-events/",
        "/api/v1/sync/pull",
        "/api/v1/notifications/",
    ],
)
async def test_skeleton_endpoints_respond(client: AsyncClient, path: str):
    response = await client.get(path)
    assert response.status_code == 200
