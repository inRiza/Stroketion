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
async def test_register_and_login(client: AsyncClient):
    register = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "test@hology.dev",
            "password": "secret123",
            "full_name": "Test User",
            "role": "patient",
        },
    )
    assert register.status_code == 200
    body = register.json()
    assert body["access_token"]
    assert body["user"]["email"] == "test@hology.dev"

    login = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "test@hology.dev",
            "password": "secret123",
            "role": "patient",
        },
    )
    assert login.status_code == 200
    assert login.json()["user"]["role"] == "patient"
