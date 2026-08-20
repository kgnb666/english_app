# AI English Coach — 项目进程计划

## 当前完成度总览

| 模块 | 后端 | 前端 | 状态 |
|------|------|------|------|
| 用户系统 | ✅ 注册/登录/JWT | ✅ 登录/注册页 | 完成 |
| AI 口语陪练 | ✅ DeepSeek 对话+纠错 | ✅ 聊天列表+聊天页 | 完成 |
| 单词学习 | ✅ CRUD+间隔复习+AI 记忆法 | ✅ 列表+详情+复习 | 完成 |
| 首页仪表盘 | ✅ 统计 API | ✅ 对接真实数据 | 完成 |
| 个人中心 | ✅ 用户信息 | ⚠️ 仅登出可用 | 基本可用 |
| 阅读助手 | ❌ | ❌ 占位 | 未开始 |
| 作文批改 | ❌ | ❌ | 未开始 |
| 语音功能 | ❌ | ❌ | 未开始 |

---

## 第一阶段：基础框架 ✅ 已完成

**目标：项目骨架 + 用户系统 + 一个核心 AI 功能**

| 任务 | 状态 |
|------|------|
| FastAPI 后端项目结构 | ✅ |
| SQLite 数据库 5 张表 | ✅ |
| 用户注册/登录 (JWT) | ✅ |
| DeepSeek AI 客户端 | ✅ |
| Flutter 项目 + Android v2 embedding | ✅ |
| 登录/注册页面 | ✅ |
| 底部导航 5 Tab | ✅ |
| APK 构建部署到真机 | ✅ |

---

## 第二阶段：核心功能 ✅ 已完成

**目标：AI 口语陪练 + 单词学习，App 可日常使用**

| 任务 | 状态 |
|------|------|
| AI 口语陪练 — 后端 ChatService | ✅ |
| AI 口语陪练 — 6 个 REST 端点 | ✅ |
| AI 口语陪练 — Flutter 聊天 UI | ✅ |
| AI 口语陪练 — 会话列表+删除 | ✅ |
| 单词学习 — 后端 VocabularyService | ✅ |
| 单词学习 — 8 个 REST 端点 | ✅ |
| 单词学习 — 20 个 CET4 种子词 | ✅ |
| 单词学习 — Flutter 列表+详情+复习 | ✅ |
| 首页仪表盘 — 统计数据 API | ✅ |
| 首页仪表盘 — 对接真实数据 | ✅ |
| 间隔复习算法 (SR) | ✅ |
| 学习活动自动记录 | ✅ |

---

## 第三阶段：阅读助手 🔜 待开发

**预估工时：后端 2h + 前端 2h**

| 任务 | 说明 |
|------|------|
| ReadingService | 翻译 + 词汇标记 + 长难句分析 + 文章总结 |
| 4 个 REST 端点 | analyze / translate / highlight / summarize |
| Flutter 阅读页 | 文章输入框 + AI 分析结果展示 |
| 前端 API 调用层 | Dart service |

---

## 第四阶段：作文批改 🔜 待开发

**预估工时：后端 2h + 前端 1.5h**

| 任务 | 说明 |
|------|------|
| WritingService | AI 评分 + 语法纠错 + 优化版生成 |
| 4 个 REST 端点 | submit / score / correct / optimize |
| Flutter 作文页 | 作文输入 + 批改结果展示 (评分/错误/优化) |
| 前端 API 调用层 | Dart service |
| 作文记录表 | 数据库已有，补 API |

---

## 第五阶段：打磨与体验 🔜 待开发

**预估工时：3h**

| 任务 | 说明 |
|------|------|
| 个人中心完善 | 学习目标设置、等级切换、学习记录 |
| 深色模式开关 | 主题代码已有，补开关逻辑 |
| 空状态/错误提示 | 各页面统一处理 |
| 下拉刷新 | 首页、单词页已有 |
| 启动页 | Splash screen |

---

## 第六阶段：语音功能 🔮 远期

**预估工时：后端 4h + 前端 3h**

| 任务 | 说明 |
|------|------|
| ASR 语音转文字 | Whisper API / 本地模型 |
| TTS 文字转语音 | Edge TTS / OpenAI TTS |
| 发音评分 | 对比标准发音 |
| 口语陪练 + 语音 | AI 对话支持语音输入输出 |

---

## 当前基础设施

| 项目 | 技术 |
|------|------|
| 后端框架 | FastAPI + Uvicorn |
| 数据库 | SQLite + SQLAlchemy (异步) |
| AI 模型 | DeepSeek (可切换 OpenAI) |
| 前端 | Flutter 3.38 + Material 3 |
| 状态管理 | Provider |
| HTTP 客户端 | Dio |
| 路由 | GoRouter |
| 构建 | Gradle + Kotlin DSL |
| 运行端口 | 后端 8002 |

---

## 启动命令

```powershell
# 后端
cd D:\english_app\backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8002

# 前端
cd D:\english_app\frontend
flutter run

# 或构建 APK
flutter build apk --debug
```

---

*最后更新: 2026-08-03*
