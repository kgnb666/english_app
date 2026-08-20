# services/auth_service.py - 用户认证 + 密码管理

from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User
from app.models.token import RefreshToken
from app.core.config import settings
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    generate_refresh_token,
    hash_token,
)
from app.schemas.user import (
    UserRegisterRequest,
    TokenResponse,
    UserProfileResponse,
)


class AuthService:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def register(self, req: UserRegisterRequest) -> TokenResponse:
        result = await self.db.execute(select(User).where(User.username == req.username))
        if result.scalar_one_or_none(): raise ValueError(f"Username '{req.username}' already exists")
        result = await self.db.execute(select(User).where(User.email == req.email))
        if result.scalar_one_or_none(): raise ValueError(f"Email '{req.email}' already registered")
        user = User(username=req.username, email=req.email, password_hash=hash_password(req.password))
        self.db.add(user); await self.db.flush()
        return await self._issue_tokens(user.id, user.username)

    async def login(self, username: str, password: str) -> TokenResponse:
        result = await self.db.execute(select(User).where(User.username == username))
        user = result.scalar_one_or_none()
        if not user or not verify_password(password, user.password_hash): raise ValueError("Invalid username or password")
        return await self._issue_tokens(user.id, user.username)

    async def refresh(self, refresh_token: str) -> TokenResponse:
        """用刷新令牌换发新 access + refresh（轮换：旧 refresh 立即失效）"""
        record = await self._get_valid_refresh(refresh_token)
        if not record:
            raise ValueError("Invalid or expired refresh token")
        # 轮换：旧 refresh 标记撤销，签发新令牌
        record.revoked = True
        user = (await self.db.execute(select(User).where(User.id == record.user_id))).scalar_one_or_none()
        if not user:
            raise ValueError("User not found")
        return await self._issue_tokens(user.id, user.username)

    async def logout(self, refresh_token: str) -> dict:
        """注销刷新令牌"""
        record = await self._get_valid_refresh(refresh_token)
        if record:
            record.revoked = True
            await self.db.flush()
        return {"message": "Logged out"}

    async def _issue_tokens(self, user_id: str, username: str) -> TokenResponse:
        """签发 access_token + refresh_token（refresh 落库存哈希）"""
        access = create_access_token(data={"sub": user_id})
        refresh = generate_refresh_token()
        self.db.add(RefreshToken(
            user_id=user_id,
            token_hash=hash_token(refresh),
            expires_at=datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        ))
        await self.db.flush()
        return TokenResponse(
            access_token=access,
            refresh_token=refresh,
            user_id=user_id,
            username=username,
        )

    async def _get_valid_refresh(self, refresh_token: str) -> RefreshToken | None:
        """按哈希查刷新令牌，校验未撤销且未过期"""
        if not refresh_token:
            return None
        r = await self.db.execute(
            select(RefreshToken).where(RefreshToken.token_hash == hash_token(refresh_token))
        )
        record = r.scalar_one_or_none()
        if not record or record.revoked:
            return None
        if record.expires_at < datetime.utcnow():
            record.revoked = True
            await self.db.flush()
            return None
        return record

    async def get_profile(self, user_id: str) -> UserProfileResponse:
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user: raise ValueError("User not found")
        return UserProfileResponse.model_validate(user)

    async def update_profile(self, user_id: str, update_data: dict) -> UserProfileResponse:
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user: raise ValueError("User not found")
        for key, value in update_data.items():
            if value is not None and hasattr(user, key): setattr(user, key, value)
        await self.db.flush()
        return UserProfileResponse.model_validate(user)

    async def change_password(self, user_id: str, old_password: str, new_password: str):
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user: raise ValueError("User not found")
        if not verify_password(old_password, user.password_hash): raise ValueError("Current password is incorrect")
        if len(new_password) < 6: raise ValueError("New password must be at least 6 characters")
        user.password_hash = hash_password(new_password)
        await self.db.flush()
        return {"message": "Password updated successfully"}
