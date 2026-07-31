# api/v1/stats.py - 学习统计相关 API 端点 (待实现)

from fastapi import APIRouter

router = APIRouter(prefix="/stats", tags=["Statistics"])

# 端点将在第二阶段实现:
# GET /stats/summary        - 学习概览 (今日数据 + 累计统计)
# GET /stats/daily          - 每日统计数据
