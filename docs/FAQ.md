# 常见问题（FAQ）

## 后端

### Q1：后端启动失败 / 端口 8002 被占用

先确认端口是否被占用：

```powershell
netstat -ano | findstr :8002
```

如被占用，换端口启动：

```powershell
.\.venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8003
```

换端口后，App 端到「个人中心 -> 服务器设置」把地址改成新端口。

### Q2：启动报缺少模块 / ModuleNotFoundError

确认已安装依赖并在正确的虚拟环境中启动：

```powershell
cd D:\english_app\backend
.\.venv\Scripts\pip install -r requirements.txt
```

如果系统里装了多个 Python，请用 `backend\.venv\Scripts\python.exe` 显式启动。

### Q3：AI 对话/阅读/作文报 503 或 ai_unavailable

AI 功能依赖 `backend/.env` 中的密钥：

- DeepSeek：`AI_PROVIDER=deepseek` + `DEEPSEEK_API_KEY=sk-xxx`
- OpenAI：`AI_PROVIDER=openai` + `OPENAI_API_KEY=sk-xxx`

检查 `.env` 是否已从 `.env.example` 复制、密钥是否正确、服务器能否访问 api.deepseek.com。

### Q4：语音转写失败

本地模式（默认 `WHISPER_PROVIDER=local`）需要 Whisper 模型文件在 `backend/models/whisper-base/`（该目录被 gitignore，需自行下载放入）。

云端模式需要配置：

```ini
WHISPER_PROVIDER=siliconflow
WHISPER_API_KEY=sk-xxx
```

### Q5：TTS 无声 / 报错

TTS 使用 Edge TTS（`edge-tts` 库），需要能访问微软服务。音频会缓存到 `backend/tts_cache/`（24 小时），缓存存在时无需联网。

### Q6：SECRET_KEY 是什么？为什么 .env 里会自动多出一行？

`SECRET_KEY` 用于 JWT 签名。留空时后端首次启动会自动生成随机密钥并写入 `backend/.env`。注意：**不要提交 .env 到 git**（已在 .gitignore 中排除）。

### Q7：数据库文件是哪些？

- `backend/english_app.db`：正式数据库（启动时自动创建）
- `backend/english_app.db.bak`：旧备份，可删除
- `backend/coach_dbg.db`：调试用，可删除
- `cet_coach_test.py` 运行时会在 backend 目录生成 `coach_test.db`，测试结束可删除

## 前端 / App

### Q8：App 连不上服务器

按优先级检查：

1. 后端已启动（浏览器访问 `http://<电脑IP>:8002/health`）
2. 手机和电脑在同一局域网
3. App 内「服务器设置」地址正确（含 `/api/v1` 后缀，如 `http://192.168.1.10:8002/api/v1`）
4. 电脑防火墙放行 8002 端口

Android 模拟器访问宿主机用 `http://10.0.2.2:8002/api/v1`；真机用电脑局域网 IP。

### Q9：为什么我改了 app_config.json 但 App 还是连旧地址？

地址解析优先级：编译期 `--dart-define` > App 内用户自定义（shared_preferences）> `app_config.json`。如果之前设置过自定义地址，会覆盖配置文件；到「服务器设置」里清除或修改即可。

### Q10：如何构建 APK？

```powershell
cd D:\english_app\frontend
flutter build apk --debug
```

产物在 `frontend/build/app/outputs/flutter-apk/app-debug.apk`。真机调试建议同时传 `--dart-define=API_BASE_URL=http://<电脑IP>:8002/api/v1`。

### Q11：学习提醒不弹？

- Android 13+ 首次开启需授权通知权限
- 部分国产 ROM 需要允许「自启动 / 后台运行」，否则进程被杀后不触发
- 提醒为本地通知（不依赖后端），时间在「个人中心 -> 学习提醒」设置

### Q12：数据备份/恢复在哪里？

「个人中心 -> 数据备份」：一键导出全部学习数据，导出文件保存在应用文档目录 `backups/`，点击可恢复。

## 功能相关

### Q13：词库怎么导入？为什么我的词库只有 20 个词？

内置只有 20 个种子词，导入完整词库：

```powershell
cd D:\english_app\backend\data
python import_words.py init --db ../english_app.db
```

内置词库约 2500 词（CET4/CET6/考研/IELTS/TOEFL），也可从 ECDICT 导入，详见 [backend/data/README.md](../backend/data/README.md)。

### Q14：单词的"已掌握/待复习"是怎么算的？

使用 SM-2 间隔复习算法：答对增加熟练度并延后复习时间，答错降级。状态依次为 `new` -> `learning` -> `review` -> `mastered`。

### Q15：CET 题目是固定的吗？

CET 阅读/听力/翻译/口语内置了一批训练材料，AI 负责解析与评分；写作和翻译的批改每次由 AI 生成。后续可扩展题库，数据在服务层 `cet_*_service.py` 中。

### Q16：怎么重置用户密码？

App 内「个人中心 -> 修改密码」可自助修改。忘记密码暂无找回流程，可联系管理员直接操作数据库，或用注册接口重新注册（用户名/邮箱会冲突，需先删除旧用户）。

### Q17：全部 UI 文案在哪改？

`frontend/lib/l10n/zh_CN.dart` 的 `AppStrings` 类。项目约定：**前端页面不硬编码中文，新文案一律追加到 AppStrings**。

## 测试与开发

### Q18：怎么运行测试？

```powershell
# 后端冒烟测试（在 backend 目录）
python cet_coach_test.py

# 前端
cd D:\english_app\frontend
flutter analyze
flutter test
```

### Q19：接口文档在哪？

- 实时 Swagger：启动后端后访问 `http://localhost:8002/docs`
- 静态清单：[API.md](API.md)

### Q20：改了后端模型，表结构不生效？

启动时 `create_all` 只会创建缺失的表，不会改已有表。开发阶段可删除 `backend/english_app.db` 重建（会丢失数据，先备份）；正式环境建议用 Alembic 迁移。
