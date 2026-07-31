# ai/client.py - AI 大模型调用客户端 (支持 DeepSeek / OpenAI 切换)

import httpx
from app.core.config import settings


class AIClient:
    """AI 模型调用客户端 - 统一接口，可切换不同的 LLM 提供商"""

    def __init__(self):
        self.provider = settings.AI_PROVIDER

        if self.provider == "deepseek":
            self.api_key = settings.DEEPSEEK_API_KEY
            self.base_url = settings.DEEPSEEK_BASE_URL
            self.model = settings.DEEPSEEK_MODEL
        else:
            self.api_key = settings.OPENAI_API_KEY
            self.base_url = settings.OPENAI_BASE_URL
            self.model = settings.OPENAI_MODEL

    async def chat(
        self,
        messages: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 2000,
    ) -> str:
        """发送对话请求到 AI 模型，返回回复文本"""
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{self.base_url}/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model,
                    "messages": messages,
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                },
            )
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"]


# 全局 AI 客户端实例
ai_client = AIClient()
