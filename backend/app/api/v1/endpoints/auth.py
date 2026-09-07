from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.schemas.common import AuthResponse, LoginRequest, MessageResponse, RegisterRequest
from app.services.auth_service import login_user, register_user

router = APIRouter()


@router.post("/register", response_model=AuthResponse)
async def register(data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    return await register_user(db, data)


@router.post("/login", response_model=AuthResponse)
async def login(data: LoginRequest, db: AsyncSession = Depends(get_db)):
    return await login_user(db, data)


@router.post("/refresh", response_model=MessageResponse)
async def refresh_token():
    return MessageResponse(message="not implemented")


@router.post("/logout", response_model=MessageResponse)
async def logout():
    return MessageResponse(message="not implemented")
