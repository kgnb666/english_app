# api/v1/auth.py - 用户认证 + 密码管理 API

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from app.core.dependencies import get_db, get_current_user_id
from app.schemas.user import (
    UserRegisterRequest,
    UserLoginRequest,
    TokenResponse,
    UserProfileResponse,
    UserUpdateRequest,
    RefreshRequest,
    LogoutRequest,
)
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])


class ChangePasswordRequest(BaseModel):
    old_password: str = Field(..., min_length=1)
    new_password: str = Field(..., min_length=6, max_length=100)


@router.post("/register", response_model=TokenResponse, status_code=201)
async def register(req: UserRegisterRequest, db: AsyncSession = Depends(get_db)):
    try: return await AuthService(db).register(req)
    except ValueError as e: raise HTTPException(status_code=409, detail=str(e))


@router.post("/login", response_model=TokenResponse)
async def login(req: UserLoginRequest, db: AsyncSession = Depends(get_db)):
    try: return await AuthService(db).login(req.username, req.password)
    except ValueError as e: raise HTTPException(status_code=401, detail=str(e))


@router.post("/refresh", response_model=TokenResponse)
async def refresh(req: RefreshRequest, db: AsyncSession = Depends(get_db)):
    """刷新令牌：换发新 access_token + refresh_token（旧 refresh 轮换失效）"""
    try: return await AuthService(db).refresh(req.refresh_token)
    except ValueError as e: raise HTTPException(status_code=401, detail=str(e))


@router.post("/logout")
async def logout(req: LogoutRequest, db: AsyncSession = Depends(get_db)):
    """退出登录：注销 refresh_token"""
    return await AuthService(db).logout(req.refresh_token)


@router.get("/me", response_model=UserProfileResponse)
async def get_profile(user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    try: return await AuthService(db).get_profile(user_id)
    except ValueError as e: raise HTTPException(status_code=404, detail=str(e))


@router.patch("/me", response_model=UserProfileResponse)
async def update_profile(req: UserUpdateRequest, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    try: return await AuthService(db).update_profile(user_id, req.model_dump(exclude_unset=True))
    except ValueError as e: raise HTTPException(status_code=404, detail=str(e))


@router.post("/change-password")
async def change_password(req: ChangePasswordRequest, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    try: return await AuthService(db).change_password(user_id, req.old_password, req.new_password)
    except ValueError as e:
        if "Current password" in str(e): raise HTTPException(status_code=400, detail=str(e))
        raise HTTPException(status_code=400, detail=str(e))
