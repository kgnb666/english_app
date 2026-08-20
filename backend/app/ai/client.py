# ai/client.py - AI 大模型调用客户端 (支持 DeepSeek / OpenAI 切换)

import httpx
import json
from app.core.config import settings

# 复用连接池，避免每次调用新建连接
_client = httpx.AsyncClient(
    timeout=httpx.Timeout(connect=10.0, read=60.0, write=30.0, pool=10.0)
)


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
        json_mode: bool = False,
        return_usage: bool = False,
    ) -> str | dict:
        """发送对话请求到 AI 模型。
        return_usage=False 时返回回复文本；
        return_usage=True 时返回 {"content": str, "usage": dict, "model": str}
        """
        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }
        if json_mode:
            payload["response_format"] = {"type": "json_object"}
        response = await _client.post(
            f"{self.base_url}/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            json=payload,
        )
        response.raise_for_status()
        data = response.json()
        content = data["choices"][0]["message"]["content"]
        if return_usage:
            return {
                "content": content,
                "usage": data.get("usage") or {},
                "model": data.get("model") or self.model,
            }
        return content

    async def stream(self, messages: list[dict], temperature: float = 0.7, max_tokens: int = 2000):
        """流式调用 AI，逐 token 产出回复文本增量（不解析 JSON）"""
        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": True,
        }
        async with _client.stream(
            "POST",
            f"{self.base_url}/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            json=payload,
        ) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if data == "[DONE]":
                    break
                try:
                    obj = json.loads(data)
                    delta = obj["choices"][0]["delta"].get("content")
                    if delta:
                        yield delta
                except (json.JSONDecodeError, KeyError, IndexError, TypeError):
                    continue


# 全局 AI 客户端实例
ai_client = AIClient()
