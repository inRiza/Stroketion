from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password, verify_password
from app.models.domain import User
from app.schemas.common import AuthResponse, LoginRequest, RegisterRequest, UserResponse


async def register_user(db: AsyncSession, data: RegisterRequest) -> AuthResponse:
    if data.role not in {"patient", "caregiver"}:
        raise HTTPException(status_code=400, detail="Role must be patient or caregiver")

    existing = await db.scalar(select(User).where(User.email == data.email))
    if existing:
        raise HTTPException(status_code=409, detail="Email already registered")

    user = User(
        email=data.email,
        hashed_password=hash_password(data.password),
        full_name=data.full_name,
        role=data.role,
        phone=data.phone,
        gender=data.gender,
        date_of_birth=data.date_of_birth,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    token = create_access_token(user.id)
    return AuthResponse(access_token=token, user=UserResponse.model_validate(user))


async def login_user(db: AsyncSession, data: LoginRequest) -> AuthResponse:
    user = await db.scalar(select(User).where(User.email == data.email))
    if not user or not verify_password(data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if data.role and user.role != data.role:
        raise HTTPException(status_code=403, detail=f"Account is registered as {user.role}")

    token = create_access_token(user.id)
    return AuthResponse(access_token=token, user=UserResponse.model_validate(user))
