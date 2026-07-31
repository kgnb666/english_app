# api/v1/vocabulary.py - 单词相关 API 端点 (待实现)

from fastapi import APIRouter

router = APIRouter(prefix="/vocabulary", tags=["Vocabulary"])

# 端点将在第二阶段实现:
# GET    /vocabulary/words          - 单词列表
# GET    /vocabulary/words/{id}     - 单词详情
# GET    /vocabulary/my-progress    - 我的学习进度
# POST   /vocabulary/words/{id}/review - 复习单词
# POST   /vocabulary/words/{id}/memory-aid - AI 生成记忆方法
