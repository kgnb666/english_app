# AI English Coach（AI 英语教练）

基于 **FastAPI + Flutter** 的 AI 英语学习 App，覆盖 CET-4 / CET-6 备考与日常英语学习场景。后端提供 AI 对话、单词学习、阅读分析、作文批改、四六级专项训练、语音（ASR / TTS / 发音评测）等能力；前端为 Android Flutter App。

> 文档最后核对：2026-08-26（与当前代码一致）

## 功能总览

| 模块 | 主要功能 | 状态 |
|------|----------|------|
| 用户系统 | 注册 / 登录 / JWT 刷新 / 修改密码 / 个人资料 | ✅ |
| AI 口语陪练 | DeepSeek 对话 + 语法纠错 + SSE 流式回复 + 会话总结 / 推荐主题 | ✅ |
| 单词学习 | 词库导入（CET4/CET6/考研/IELTS/TOEFL）、SM-2 间隔复习、AI 记忆法、测验（选择/拼写/听音）、生词本、真题例句、单词音频 | ✅ |
| 阅读助手 | AI 文章分析（翻译 / 词汇 / 长难句 / 总结）+ 历史记录 | ✅ |
| 作文批改 | AI 评分 + 语法纠错 + 优化版生成 + 历史记录 | ✅ |
| 学习统计 | 首页仪表盘、周 / 月统计、学习日历、真实学习计时 | ✅ |
| 学习计划 | 每日任务模板 + 今日任务自动生成与进度跟踪 | ✅ |
| 个人中心 | 英语等级、每日目标、学习画像（弱项/偏好）、错误记录、深色模式 | ✅ |
| 语音功能 | 语音转写 ASR（本地 Whisper / 云端）、TTS（Edge TTS）、发音评测 | ✅ |
| CET 备考 | 目标设定与阶段计划、阅读、听力、写作、翻译、口语模拟、AI 教练 | ✅ |
| 数据备份 | 一键导出 / 恢复全部学习数据 | ✅ |
| 学习提醒 | 本地定时通知（每日提醒 + 点击跳转） | ✅ |
| 服务器设置 | App 内配置 API 地址 + 连接测试 | ✅ |

## 技术架构

| 端 | 技术栈 |
|----|--------|
| 后端 | FastAPI + Uvicorn、SQLAlchemy 2（异步）、SQLite、Pydantic v2、DeepSeek / OpenAI API、Edge TTS、faster-whisper |
| 前端 | Flutter 3.38+、Dart、Provider、GoRouter、Dio、flutter_local_notifications、sqflite、fl_chart |
| 运行端口 | 后端 `8002`，API 基础路径 `/api/v1` |

```
┌─────────────────────────────┐
│      Flutter Android App    │
│  Provider / GoRouter / Dio  │
└──────────────┬──────────────┘
               │ HTTP (JSON / SSE / multipart)
┌──────────────▼──────────────┐
│     FastAPI 后端 (:8002)    │
│  /api/v1 路由 + 业务 Service │
└───────┬──────────────┬──────┘
        │              │
   SQLite 数据库    AI 服务
   (SQLAlchemy)   DeepSeek/OpenAI
                  Edge TTS / Whisper
```

## 目录结构

```
english_app/
├── backend/                 # FastAPI 后端
│   ├── app/
│   │   ├── main.py          # 应用入口 + 路由注册 + 全局异常处理
│   │   ├── api/v1/          # 路由（19 个模块，88 个接口）
│   │   ├── models/          # SQLAlchemy 模型（26 张表）
│   │   ├── schemas/         # Pydantic 请求/响应模型
│   │   ├── services/        # 业务逻辑（AI 调用、统计、导入等）
│   │   ├── ai/              # AI 客户端与提示词
│   │   └── core/            # 配置、依赖、安全、日志
│   ├── alembic/             # 迁移目录（当前由 create_all 自动建表）
│   ├── data/                # 词库导入工具（import_words.py）
│   ├── models/whisper-base/ # 本地 Whisper 模型（gitignore）
│   ├── static/              # 静态音频资源（gitignore）
│   ├── tts_cache/           # TTS 磁盘缓存（gitignore）
│   ├── requirements.txt
│   └── .env.example         # 配置模板（复制为 .env 使用）
├── frontend/                # Flutter App
│   ├── lib/
│   │   ├── app.dart         # GoRouter 路由与底部导航
│   │   ├── pages/           # 全部页面
│   │   ├── services/        # API 调用与业务状态
│   │   ├── widgets/         # 通用组件
│   │   └── l10n/zh_CN.dart  # 全部 UI 文案（AppStrings）
│   └── test/                # Flutter 测试
├── docs/
│   ├── API.md               # 接口文档（88 个接口）
│   ├── DATABASE.md          # 数据库表结构
│   └── FAQ.md               # 常见问题
├── PROJECT_PLAN.md          # 项目进程计划
├── IMPROVEMENT_PLAN.md      # 改进计划与完成状态
├── CHANGELOG.md             # 变更记录
└── start_backend.bat        # Windows 一键启动后端
```

## 快速开始

### 1. 启动后端

环境要求：Python 3.10+（推荐 3.11）。

```powershell
cd D:\english_app\backend

# 首次：创建虚拟环境并安装依赖
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt

# 首次：复制配置模板并填入密钥
copy .env.example .env

# 启动（端口 8002）
.\.venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8002
```

也可以直接双击项目根目录的 `start_backend.bat`。

启动后可访问：

- 健康检查：<http://localhost:8002/health>
- 接口文档（Swagger）：<http://localhost:8002/docs>

> 所有 AI 功能（对话 / 阅读 / 作文 / CET 等）需要先在 `backend/.env` 中配置 `DEEPSEEK_API_KEY`；语音转写默认使用本地 Whisper 模型，需将模型放在 `backend/models/whisper-base/`。

### 2. 导入词库（可选）

后端内置词库工具支持 CET4 / CET6 / 考研 / IELTS / TOEFL 约 2500 词，直连数据库导入：

```powershell
cd D:\english_app\backend\data
python import_words.py init --db ../english_app.db
```

详见 [backend/data/README.md](backend/data/README.md)。

### 3. 运行前端

环境要求：Flutter 3.38+（Dart SDK 3.2+）。

```powershell
cd D:\english_app\frontend
flutter pub get

# Android 模拟器（10.0.2.2 指向宿主机）
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8002/api/v1

# 真机（指向电脑局域网 IP，端口 8002）
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8002/api/v1
```

构建调试 APK：

```powershell
flutter build apk --debug
```

App 内也可以随时通过「个人中心 -> 服务器设置」修改 API 地址并测试连接，优先级高于编译期配置。

## 测试

```powershell
# 后端冒烟测试（在 backend 目录下）
cd D:\english_app\backend
python cet_coach_test.py

# 前端静态分析 + 单元/组件测试
cd D:\english_app\frontend
flutter analyze
flutter test
```

## 文档索引

| 文档 | 说明 |
|------|------|
| [PROJECT_PLAN.md](PROJECT_PLAN.md) | 项目进程计划与完成度 |
| [IMPROVEMENT_PLAN.md](IMPROVEMENT_PLAN.md) | 改进任务清单与完成状态 |
| [docs/API.md](docs/API.md) | 后端接口文档（88 个接口） |
| [docs/DATABASE.md](docs/DATABASE.md) | 数据库表结构 |
| [docs/FAQ.md](docs/FAQ.md) | 常见问题 |
| [backend/README.md](backend/README.md) | 后端部署与配置说明 |
| [frontend/README.md](frontend/README.md) | 前端说明 |
| [backend/data/README.md](backend/data/README.md) | 词库导入工具 |
| [CHANGELOG.md](CHANGELOG.md) | 变更记录 |
