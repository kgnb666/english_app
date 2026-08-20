# AI 英语教练 — 完善计划（给 AI 的施工指南）

## 项目位置
- 后端：`D:\english_app\backend\`（FastAPI + SQLAlchemy + SQLite）
- 前端：`D:\english_app\frontend\`（Flutter 3.38 + Provider + GoRouter）
- API 基础路径：`/api/v1`
- 所有面向用户的文案统一在 `frontend/lib/l10n/zh_CN.dart` 的 `AppStrings` 类中

## 工作原则
1. 每个任务做完后自测：后端改完手工验证端点，前端改完确保 `flutter analyze` 无新增 error
2. 所有 catch 不要空吞 — 至少打印 `debugPrint(e.toString())`
3. 新增文案全部追加到 `AppStrings`，绝对不要在前端页面里硬编码中文字符串
4. 后端新增表后在 API 端点 return 时用 dict 序列化（不要直接返回 ORM 对象）

---

## 任务 1：扩充词库

**目标**：从 20 个种子词扩充到完整的 CET4 词库

### 后端
1. 在项目根目录创建一个 `data/` 文件夹
2. 写一个 Python 脚本 `data/import_words.py`，内容：
   - 用 `httpx` 从 ECDICT（`https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv`）下载 CSV（如果网络不通则使用内置的硬编码词库 fallback，至少包含 500 个常用 CET4 词）
   - 调用 `POST /api/v1/vocabulary/seed` 逐批写入（每次 50 个，避免超时）
   - 脚本启动时先从本地 SQLite 查询已有词数，跳过已存在的

3. 改造 `POST /vocabulary/seed` 端点：
   - 当前 `seed_words()` 接受 list 但端点固定用硬编码的 20 个词
   - 增加一个接受 `{"words": [...]}` JSON body 的版本，支持批量导入任意词表
   - 保留原有无 body 的 POST 行为（向后兼容）

4. 给 `/vocabulary/words` 端点增加 `search` query 参数：
   - 支持按单词文本模糊搜索（WHERE word LIKE '%keyword%'）
   - `VocabularyService.get_words()` 方法签名加 `search: Optional[str] = None`

### 前端
5. 在单词列表页 `vocabulary_page.dart` 顶部加搜索框：
   - 用 `TextField` + `onChanged` 做本地搜索过滤（200ms debounce）
   - 如果词库超过 100 个，前端本地过滤可能不全，改为调 API 搜索
   - 搜索框带清除按钮

---

## 任务 2：阅读/作文历史记录

**目标**：分析过的文章和批改过的作文自动保存，支持查看历史

### 后端 — 数据库模型
1. 新建 `backend/app/models/reading.py`：
```python
class ReadingRecord(Base):
    __tablename__ = "reading_records"
    id: str (UUID4 PK)
    user_id: str (FK -> users.id, indexed)
    article: str (Text, 原文前 2000 字符)
    result: dict (JSON, AI 分析结果)
    created_at: datetime
```

2. 新建 `backend/app/models/writing.py`：
```python
class WritingRecord(Base):
    __tablename__ = "writing_records"
    id: str (UUID4 PK)
    user_id: str (FK -> users.id, indexed)
    essay: str (Text, 原文前 2000 字符)
    result: dict (JSON, AI 批改结果)
    created_at: datetime
```

3. 在 `backend/app/models/__init__.py` 中导入新模型

### 后端 — 服务层和 API
4. 修改 `ReadingService.analyze()`：分析完成后，将原文和结果写入 `reading_records`
5. 修改 `WritingService.review()`：批改完成后，将原文和结果写入 `writing_records`
6. 两个 service 各加 `get_history(user_id)` 方法返回最近 50 条记录
7. 两个路由文件增加：
   - `GET /reading/history` → 返回阅读历史列表（id, article前50字, created_at）
   - `GET /reading/history/{record_id}` → 返回单条记录全文
   - `GET /writing/history` → 返回作文历史列表
   - `GET /writing/history/{record_id}` → 返回单条记录全文

### 前端
8. 阅读页 `reading_page.dart`：分析完成后在底部增加"历史记录"入口（`ListView` 展示最近 10 条，点击可回看）
9. 作文页 `writing_page.dart`：同上
10. 新建两个 Dart 数据模型文件（或在 `reading_service.dart`/`writing_service.dart` 里补充 history 相关 model 和方法）

---

## 任务 3：安全与可配置性

**目标**：消灭硬编码，让 App 可在不同环境运行

### 后端
1. 生成随机 SECRET_KEY：
   - 在 `backend/.env` 中用 `openssl rand -hex 32` 生成的随机值替换默认 key
   - 或者写一个启动检查：如果还是默认值则自动生成并写入 .env

2. 增加请求频率限制（可选）：
   - 用简单的内存字典记录每个 user_id 每分钟的请求次数
   - 对 AI 调用端点（chat/send、reading/analyze、writing/review）限制每分钟 10 次

### 前端
3. 服务器地址可配置：
   - `api_config.dart` 里保留默认值（如 `http://10.0.2.2:8002/api/v1` 作为模拟器默认）
   - 在 `shared_preferences` 中存储用户自定义的服务器地址
   - 如果用户没有设置过则用默认值
   - `ApiService` 初始化时从 `shared_preferences` 读取

4. 在 Profile 页增加"服务器设置"入口：
   - 点击后弹出对话框，让用户输入 IP:端口
   - 保存后 `ApiService` 下次请求用新地址
   - 加一个"测试连接"按钮，发 GET `/health` 验证

5. 登录页增加"修改服务器"的小字链接，方便首次使用时配置

---

## 任务 4：学习提醒

**目标**：App 在设定时间弹出本地通知

### 后端
1. 在 `PATCH /auth/me` 中支持更新 `reminder_enabled`（bool）和 `reminder_time`（HH:MM 字符串）
2. `User` 模型增加两个字段：
   - `reminder_enabled: bool = False`
   - `reminder_time: str | None = None` （如 "09:00"）

### 前端
3. `pubspec.yaml` 添加 `flutter_local_notifications: ^18.0.0`
4. 在 `main.dart` 中初始化通知插件
5. 在 Profile 页增加"每日提醒"开关 + 时间选择器
6. 设置提醒后，用 `flutter_local_notifications` 的 `periodicallyShow` 每天定时弹通知
7. 通知内容："该学英语了！今日目标：{goal_minutes}分钟 + {goal_words}个单词"
8. Profile 页的 reminder 开关变更时同步调 `PATCH /auth/me`

---

## 任务 5：单词测验模式

**目标**：不只是"记住/再练"二选一，增加选择题和拼写题

### 后端
1. 新增端点 `POST /vocabulary/quiz/generate`：
   - 返回 10 道选择题，格式：`[{word_id, question: "abandon 的中文意思是？", options: ["放弃", "获得", "加速", "适应"], correct_index: 0}]`
   - 干扰项从其他词的中文释义中随机抽取
   - 也可以调 AI 生成整份测验（用 prompt 让 AI 返回 JSON 数组）

2. 新增端点 `POST /vocabulary/quiz/result`：
   - 接受 `{answers: [{word_id, correct: true/false}]}`
   - 对答错的词不扣 progress，答对的词 progress.review_count += 1
   - 返回本局统计：`{total, correct_count, wrong_words: [...]}`

### 前端
3. 在单词详情页增加"测验模式"按钮（仅当 `status != 'new'` 时显示）
4. 新建 `quiz_page.dart`：
   - 顶部显示进度条（第 N/10 题）
   - 中间显示题目（英文单词）
   - 下方 4 个选项按钮（中文释义）
   - 选完后显示对错反馈（绿色✓/红色✗ + 正确答案高亮）
   - 0.8 秒后自动进入下一题
   - 最后一题完成后跳转结果页（分数 + 环形图 + 错词列表）
5. 结果页支持"重做错题"和"返回词库"

---

## 任务 6：错误处理改进

**目标**：不再静默吞错，用户能知道哪里出了问题

### 后端
1. 所有 service 方法统一异常处理：
   - 数据库操作错误 → 返回 `{"error": "数据库错误", "detail": str(e)}`
   - AI 调用失败 → 返回 `{"error": "AI服务暂时不可用，请稍后重试"}`
   - 参数验证 → 用 Pydantic 的 Field 增加更清晰的错误消息

2. 后端增加全局异常处理器（在 `main.py` 里）：
   - 捕获 `ValueError` → 400
   - 捕获未处理异常 → 500 + 记录日志

### 前端
3. 给所有 service 类增加错误回调或返回 Result 类型
4. 在 `ApiService` 的 Dio 拦截器中统一处理错误：
   - 401 → 跳转登录页
   - 500 → 提示"服务器错误"
   - 网络不通 → 提示"无法连接服务器，请检查网络和服务器地址"
5. Error 页面统一用 `SnackBar` 显示（红色背景 + 图标 + 错误文案），而不是只在页面里显示灰色文字

---

## 任务 7：其他小改进

按优先级排列：

### 7a. 密码修改
- 后端新增 `POST /auth/change-password`（接受 `old_password` + `new_password`）
- Profile 页增加"修改密码"入口 → 弹窗输入新旧密码

### 7b. 启动页完善
- 当前 `SplashPage` 检查 token → 有效跳首页、无效跳登录
- 加一个 1.5 秒的渐入动画（FadeTransition + ScaleTransition）
- 加 App 图标和 "AI 英语教练" 标语

### 7c. 单词详情页加 "加入生词本"
- 在 `UserWordProgress` 增加 `is_bookmarked: bool` 字段
- 详情页右上角书签按钮
- 单词列表新增 "生词本" Tab

### 7d. 对话页的 TTS 语速可调
- 聊天页 AppBar 加一个语速滑块（0.3x ~ 1.0x）
- 值存 `shared_preferences`

### 7e. 首页通知铃点进去
- 做一个"学习提醒"子页面或底部弹窗
- 展示连续打卡日历（类似 GitHub 贡献图）
- 展示近 7 天学习时长柱状图（后端已有 `/stats/weekly`）

---

## 不在此次范围内的（以后做）

- 云端同步 / 数据导入导出
- 多语言 i18n
- CI/CD
- 自动化测试
- 应用商店发布
- 离线模式
- 发音评测

---

## 启动验证

每完成一个任务后：
```bash
# 后端
cd D:\english_app\backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8002

# 前端分析
cd D:\english_app\frontend
flutter analyze
```
