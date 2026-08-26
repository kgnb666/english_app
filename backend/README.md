# 后端服务（FastAPI）

AI English Coach 的后端，提供 REST API（基础路径 `/api/v1`）与 SSE 流式对话，承载 AI 对话、单词学习、阅读/作文批改、CET 专项训练、语音转写/合成、发音评测、统计与备份等全部能力。

## 技术栈

- FastAPI + Uvicorn
- SQLAlchemy 2（异步） + SQLite（`aiosqlite`）
- Pydantic v2（请求/响应校验）
- DeepSeek / OpenAI（AI 对话，可切换）
- faster-whisper（本地语音转写，可切云端）
- Edge TTS（文字转语音，含内存 + 磁盘缓存）
- python-jose + passlib（JWT 认证）

## 目录结构

```
backend/
├── app/
│   ├── main.py              # 入口：路由注册、CORS、全局异常处理
│   ├── api/v1/              # 19 个路由模块（88 个接口）
│   ├── models/              # SQLAlchemy 模型（26 张表）
│   ├── schemas/             # Pydantic 请求/响应模型
│   ├── services/            # 业务逻辑层
│   ├── ai/                  # AI 客户端（DeepSeek/OpenAI）与提示词
│   └── core/                # 配置、依赖注入、安全、日志
├── alembic/                 # 迁移目录（当前由 create_all 自动建表）
├── data/                    # 词库导入工具（import_words.py + builtin_words.csv）
├── models/whisper-base/     # 本地 Whisper 模型（gitignore，需自行放置）
├── static/                  # 静态音频资源（gitignore，运行时生成）
├── tts_cache/               # TTS 磁盘缓存（gitignore，运行时生成）
├── requirements.txt
└── .env.example             # 配置模板（复制为 .env）
```

## 环境要求

- Python 3.10+（推荐 3.11）
- 可选：DeepSeek / OpenAI API Key（AI 功能）
- 可选：本地 Whisper 模型（默认 `models/whisper-base/`，首次转写自动加载）

## 快速开始

```powershell
cd D:\english_app\backend

# 1. 创建虚拟环境并安装依赖
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt

# 2. 创建配置文件并填写密钥
copy .env.example .env
notepad .env

# 3. 启动服务
.\.venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8002
```

也可以双击项目根目录的 `start_backend.bat` 一键启动。

启动后：

- 健康检查：`GET http://localhost:8002/health`
- 交互式文档：`http://localhost:8002/docs`（Swagger UI）
- API 基础路径：`http://localhost:8002/api/v1`

首次启动会自动创建 SQLite 数据库文件（默认 `backend/english_app.db`）并建表。

## 环境变量配置

所有配置通过 `backend/.env` 加载（`app/core/config.py`），模板见 [.env.example](.env.example)。

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `APP_NAME` | `AI English Coach` | 应用名 |
| `APP_VERSION` | `0.1.0` | 版本号 |
| `DEBUG` | `true` | 调试模式（打印 SQL、500 返回 detail） |
| `DATABASE_URL` | `sqlite+aiosqlite:///./english_app.db` | 数据库连接串 |
| `SECRET_KEY` | （自动生成） | JWT 签名密钥；为空时启动自动生成并写入 .env |
| `ALGORITHM` | `HS256` | JWT 算法 |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `120` | access token 有效期（分钟） |
| `REFRESH_TOKEN_EXPIRE_DAYS` | `5` | refresh token 有效期（天） |
| `AI_PROVIDER` | `deepseek` | AI 提供商：`deepseek` / `openai` |
| `DEEPSEEK_API_KEY` | 空 | DeepSeek API Key |
| `DEEPSEEK_BASE_URL` | `https://api.deepseek.com` | DeepSeek 接口地址 |
| `DEEPSEEK_MODEL` | `deepseek-chat` | DeepSeek 模型名 |
| `OPENAI_API_KEY` | 空 | OpenAI API Key |
| `OPENAI_BASE_URL` | `https://api.openai.com/v1` | OpenAI 接口地址 |
| `OPENAI_MODEL` | `gpt-4o` | OpenAI 模型名 |
| `WHISPER_PROVIDER` | `local` | 语音转写：`local`（faster-whisper）/ `siliconflow` / `openai` |
| `WHISPER_MODEL` | `models/whisper-base` | 本地 Whisper 模型路径 |
| `WHISPER_API_KEY` | 空 | 云端转写 API Key |
| `WHISPER_BASE_URL` | `https://api.siliconflow.cn/v1` | 云端转写接口地址 |
| `WHISPER_MODEL_NAME` | `openai/whisper-large-v3` | 云端转写模型名 |
| `CORS_ORIGINS` | `["*"]` | 允许的跨域来源（JSON 数组） |

## AI 配置示例

DeepSeek（默认）：

```ini
AI_PROVIDER=deepseek
DEEPSEEK_API_KEY=sk-xxxx
```

OpenAI：

```ini
AI_PROVIDER=openai
OPENAI_API_KEY=sk-xxxx
```

语音转写：本地模型（免费，默认）需将 faster-whisper 模型目录放到 `WHISPER_MODEL` 指定路径；云端模式需配置 `WHISPER_API_KEY`：

```ini
WHISPER_PROVIDER=siliconflow
WHISPER_API_KEY=sk-xxxx
```

## 数据库

- 默认数据库文件：`backend/english_app.db`（SQLite）
- 启动时通过 `Base.metadata.create_all` 自动建表（26 张表），无需手工迁移
- 表结构说明见 [../docs/DATABASE.md](../docs/DATABASE.md)
- 备份：App 内「个人中心 -> 数据备份」导出/恢复；或直接复制数据库文件

## 词库导入

```powershell
cd D:\english_app\backend\data
python import_words.py init --db ../english_app.db
```

详细用法见 [data/README.md](data/README.md)。

## 测试

```powershell
# 后端冒烟测试（注册/登录/CET 辅导核心链路，使用独立测试库）
cd D:\english_app\backend
python cet_coach_test.py
```

## 接口文档

- 完整接口清单：见 [../docs/API.md](../docs/API.md)
- 实时交互式文档：启动后访问 `http://localhost:8002/docs`

## 常见问题

- **AI 接口报 503 / ai_unavailable**：检查 `.env` 中 `DEEPSEEK_API_KEY`（或 OpenAI 配置）是否正确、网络是否可达。
- **语音转写失败**：本地模式确认 `backend/models/whisper-base/` 模型文件存在；云端模式确认 `WHISPER_API_KEY` 已配置。
- **端口被占用**：改用其他端口（如 `--port 8003`），并同步在 App「服务器设置」中更新地址。
- **数据库位置**：默认在 `backend/english_app.db`；`coach_dbg.db` 为调试库，可删除。

更多见 [../docs/FAQ.md](../docs/FAQ.md)。
