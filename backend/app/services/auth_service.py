# services/auth_service.py - 用户认证业务逻辑

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.core.security import hash_password, verify_password, create_access_token
from app.schemas.user import UserRegisterRequest, TokenResponse, UserProfileResponse


class AuthService:
    """认证服务 - 注册、登录、用户信息管理"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def register(self, req: UserRegisterRequest) -> TokenResponse:
        """用户注册：创建新用户并返回 JWT token"""
        # 检查用户名是否已存在
        result = await self.db.execute(
            select(User).where(User.username == req.username)
        )
        if result.scalar_one_or_none():
            raise ValueError(f"Username '{req.username}' already exists")

        # 检查邮箱是否已存在
        result = await self.db.execute(
            select(User).where(User.email == req.email)
        )
        if result.scalar_one_or_none():
            raise ValueError(f"Email '{req.email}' already registered")

        # 创建用户
        user = User(
            username=req.username,
            email=req.email,
            password_hash=hash_password(req.password),
        )
        self.db.add(user)
        await self.db.flush()

        # 生成 token
        token = create_access_token(data={"sub": user.id})
        return TokenResponse(
            access_token=token,
            user_id=user.id,
            username=user.username,
        )

    async def login(self, username: str, password: str) -> TokenResponse:
        """用户登录：验证凭证并返回 JWT token"""
        result = await self.db.execute(
            select(User).where(User.username == username)
        )
        user = result.scalar_one_or_none()

        if not user or not verify_password(password, user.password_hash):
            raise ValueError("Invalid username or password")

        token = create_access_token(data={"sub": user.id})
        return TokenResponse(
            access_token=token,
            user_id=user.id,
            username=user.username,
        )

    async def get_profile(self, user_id: str) -> UserProfileResponse:
        """获取用户个人信息"""
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise ValueError("User not found")
        return UserProfileResponse.model_validate(user)

    async def update_profile(self, user_id: str, update_data: dict) -> UserProfileResponse:
        """更新用户个人信息"""
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise ValueError("User not found")

        for key, value in update_data.items():
            if value is not None and hasattr(user, key):
                setattr(user, key, value)

        await self.db.flush()
        return UserProfileResponse.model_validate(user)
