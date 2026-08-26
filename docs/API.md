# API 接口文档

AI English Coach 后端接口全量说明，覆盖 19 个路由模块、88 个接口。

## 基础信息

| 项目 | 值 |
|------|-----|
| Base URL | `http://<host>:8002/api/v1` |
| 交互式文档 | `http://<host>:8002/docs`（Swagger UI） |
| 数据格式 | JSON（上传录音为 `multipart/form-data`） |
| 流式对话 | Server-Sent Events（SSE） |

## 认证

除注册、登录、刷新令牌和健康检查外，所有接口都需要请求头：

```
Authorization: Bearer <access_token>
```

登录/注册返回 `access_token`（短期）与 `refresh_token`（5 天，可轮换）。`access_token` 过期时调用 `POST /auth/refresh` 换发新令牌；退出登录时调用 `POST /auth/logout` 注销 `refresh_token`。

App 端行为：收到 401 自动跳转登录页。

## 统一响应结构

成功响应直接返回业务数据；失败响应统一为：

```json
{
  "code": "VALIDATION_ERROR",
  "message": "可读的错误信息",
  "detail": "详细原因"
}
```

| 错误码 | HTTP 状态 | 场景 |
|--------|-----------|------|
| `VALIDATION_ERROR` | 400 / 422 | 参数校验失败、业务校验失败 |
| `UNAUTHORIZED` | 401 | 未登录 / 令牌无效 |
| `FORBIDDEN` | 403 | 无权限 |
| `NOT_FOUND` | 404 | 资源不存在 |
| `CONFLICT` | 409 | 注册用户名/邮箱已存在 |
| `INTERNAL_ERROR` | 500 | 服务器内部错误 |
| `ai_unavailable` | 503 | AI 服务暂时不可用（可重试） |

---

## 1. 认证 Auth（`/auth`）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/auth/register` | 注册（201） |
| POST | `/auth/login` | 登录 |
| POST | `/auth/refresh` | 刷新令牌（旧 refresh 轮换失效） |
| POST | `/auth/logout` | 退出登录（注销 refresh_token） |
| GET | `/auth/me` | 获取个人信息 |
| PATCH | `/auth/me` | 更新个人信息 |
| POST | `/auth/change-password` | 修改密码 |

注册请求：

```json
{
  "username": "alice",
  "email": "alice@example.com",
  "password": "123456"
}
```

注册/登录响应（`TokenResponse`）：

```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "bearer",
  "user_id": "uuid",
  "username": "alice"
}
```

更新个人信息（`PATCH /auth/me`，字段均可选）：

```json
{
  "english_level": "intermediate",
  "daily_goal_minutes": 30,
  "daily_goal_words": 20,
  "avatar_url": "https://..."
}
```

修改密码：

```json
{
  "old_password": "123456",
  "new_password": "654321"
}
```

---

## 2. AI 口语陪练 Chat（`/chat`）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/chat/sessions?topic=可选` | 创建会话（201） |
| GET | `/chat/sessions` | 会话列表 |
| GET | `/chat/topics` | 按用户等级推荐聊天主题 |
| GET | `/chat/sessions/{session_id}` | 会话详情（含消息） |
| DELETE | `/chat/sessions/{session_id}` | 删除会话（204） |
| POST | `/chat/sessions/{session_id}/messages` | 发送消息（AI 回复+语法纠错） |
| POST | `/chat/sessions/{session_id}/messages/stream` | 流式对话（SSE） |
| POST | `/chat/sessions/{session_id}/summary` | AI 生成会话总结 |

发送消息请求：

```json
{ "content": "Hello, how are you?" }
```

流式接口返回 SSE 事件，事件类型通过 `data:` 中的 JSON 字段区分：

| 事件 | 说明 |
|------|------|
| `chunk` | AI 回复增量文本 |
| `corrections` | 语法纠错结果 |
| `done` | 回复结束 |
| `error` | 出错（可重试） |

---

## 3. 单词学习 Vocabulary（`/vocabulary`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/vocabulary/words` | 单词列表（分页/搜索/筛选） |
| GET | `/vocabulary/words/{word_id}` | 单词详情 |
| GET | `/vocabulary/words/{word_id}/examples` | 单词真题例句列表 |
| POST | `/vocabulary/words/{word_id}/examples` | 录入真题例句 |
| POST | `/vocabulary/cet/annotate` | 标注四六级词汇等级（核心/高频/易错） |
| POST | `/vocabulary/cet/seed-examples` | 写入内置四六级真题例句（幂等） |
| GET | `/vocabulary/my-progress` | 我的学习进度 |
| POST | `/vocabulary/words/{word_id}/start` | 开始学习一个单词 |
| POST | `/vocabulary/words/{word_id}/review?correct=true` | 复习打卡（SM-2） |
| POST | `/vocabulary/words/{word_id}/memory-aid` | AI 生成记忆方法 |
| POST | `/vocabulary/words/{word_id}/audio` | 生成并绑定单词音频，返回 `audio_url` |
| POST | `/vocabulary/audio/warmup` | 批量预生成词库音频 |
| GET | `/vocabulary/summary` | 单词学习概览 |
| GET | `/vocabulary/bookmarks` | 生词本列表 |
| POST | `/vocabulary/bookmark` | 收藏单词（词库不存在时自动创建） |
| DELETE | `/vocabulary/bookmark/{word_id}` | 取消收藏 |
| POST | `/vocabulary/seed` | 批量导入单词（201） |
| GET | `/vocabulary/test/generate` | 生成测验题 |
| POST | `/vocabulary/test/submit` | 提交测验答案 |
| GET | `/vocabulary/test/history` | 测验历史 |

### 单词列表查询参数

`GET /vocabulary/words` 支持：

| 参数 | 说明 |
|------|------|
| `status` | `new` / `learning` / `review` / `mastered` |
| `category` | 分类，如 CET4 / CET6 |
| `search` | 单词模糊搜索 |
| `exam_type` | CET4 / CET6 |
| `word_level` | `core` / `high_freq` / `rare_meaning` / `error_prone` |
| `page` / `page_size` | 分页，默认 1 / 20 |

响应：

```json
{
  "items": [{ "id": "uuid", "word": "abandon", "phonetic": "/əˈbændən/", "chinese_definition": "放弃；抛弃", "difficulty": "easy", "category": "CET4", "audio_url": "/static/xxx.mp3" }],
  "total": 2500,
  "page": 1,
  "page_size": 20
}
```

### 批量导入

`POST /vocabulary/seed`，请求体可选；不带请求体时写入内置种子词（向后兼容）。

```json
{
  "words": [
    {
      "word": "abandon",
      "phonetic": "/əˈbændən/",
      "part_of_speech": "v.",
      "meaning": "放弃；抛弃",
      "example": [{"en": "He abandoned his plan.", "cn": "他放弃了计划。"}],
      "difficulty": "easy",
      "category": "CET4"
    }
  ]
}
```

字段兼容 `meaning` / `chinese_definition` / `translation`，`example` / `example_sentences`。响应返回 `{"message", "total", "added"}`。

### 收藏生词

```json
{
  "word": "serendipity",
  "chinese_definition": "意外发现珍宝的运气",
  "source": "reading",
  "context": "Serendipity led her to the discovery."
}
```

`source` 取值：`manual` / `reading` / `chat`。

### 测验

生成题目：`GET /vocabulary/test/generate?test_type=choice&count=5`

`test_type`：`choice`（选择题）/ `spelling`（拼写）/ `listening`（听音）。

提交答案：

```json
{
  "test_type": "choice",
  "answers": [
    { "word_id": "uuid", "answer": "放弃" }
  ]
}
```

响应：`{"score", "total", "accuracy", "results": [...]}`。测验结果会通过 SM-2 影响单词熟练度。

---

## 4. 阅读助手 Reading（`/reading`）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/reading/analyze` | AI 分析文章（翻译/词汇/长难句/总结），自动保存记录 |
| GET | `/reading/history?page=&page_size=` | 历史列表 |
| GET | `/reading/history/{record_id}` | 历史详情 |
| DELETE | `/reading/history/{record_id}` | 删除记录 |

```json
{
  "article": "Your article text here (10-3000 chars)..."
}
```

分析响应包含 `summary_cn`、`vocabulary`、`complex_sentences`、`main_idea` 等 AI 生成字段。

---

## 5. 作文批改 Writing（`/writing`）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/writing/review` | AI 批改作文（评分/纠错/优化），自动保存记录 |
| GET | `/writing/history?page=&page_size=` | 历史列表 |
| GET | `/writing/history/{record_id}` | 历史详情 |
| DELETE | `/writing/history/{record_id}` | 删除记录 |

```json
{
  "essay": "Your essay text here (10-3000 chars)..."
}
```

批改响应包含 `score`、`errors`、`suggestions`、`optimized` 等字段。

---

## 6. 学习统计 Stats（`/stats`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/stats/dashboard` | 首页仪表盘汇总 |
| GET | `/stats/weekly` | 近 7 天每日统计 |
| GET | `/stats/monthly?year=&month=` | 月度统计（汇总+每日明细） |
| GET | `/stats/calendar?year=&month=` | 学习日历 |
| POST | `/stats/sessions` | 开始一次真实学习计时 |
| POST | `/stats/sessions/{session_id}/end` | 结束计时并按真实时长累计 |
| POST | `/stats/record?activity_type=&amount=` | 记录学习活动 |

开始计时：

```json
{ "session_type": "chat" }
```

`session_type`：`chat` / `words` / `reading` / `writing`。

结束计时：

```json
{ "duration_seconds": 1500 }
```

---

## 7. 学习计划 Plan（`/plan`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/plan/today` | 今日任务（进度来自真实学习数据） |
| GET | `/plan` | 当前计划模板 |
| PUT | `/plan` | 更新计划模板 |

```json
{
  "tasks": [
    { "task_type": "words", "target_count": 20, "enabled": true },
    { "task_type": "ai_minutes", "target_count": 30, "enabled": true }
  ]
}
```

`task_type`：`words` / `ai_minutes` / `reading` / `writing`。

---

## 8. 个人中心 / 学习画像 Profile（`/profile`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/profile` | 获取学习画像 |
| PUT | `/profile` | 更新学习画像 |
| GET | `/profile/errors?limit=` | 错误记录列表 + 类型聚合摘要 |
| DELETE | `/profile/errors/{error_id}` | 删除错误记录 |

```json
{
  "english_level": "intermediate",
  "goal": "通过四级考试",
  "vocabulary_size": 3000,
  "weak_skills": ["past_tense", "listening"],
  "preferences": { "focus": ["口语"], "topics": ["科技"], "style": "轻松聊天" }
}
```

---

## 9. 发音评测 Pronunciation（`/pronunciation`）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/pronunciation/evaluate` | 发音评测（AI 评分+错误音节+建议） |
| GET | `/pronunciation/history?limit=` | 评测历史 |

```json
{
  "target_text": "The quick brown fox jumps over the lazy dog.",
  "recognized_text": "The quick brown fox jump over the lazy dog",
  "confidence": 0.92
}
```

---

## 10. 语音合成 TTS（`/tts`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/tts?text=&voice=` | 合成 MP3 音频（Edge TTS，24h 缓存） |

参数：`text`（1-500 字符）、`voice`（支持 `en-US-AriaNeural`、`en-US-JennyNeural`、`en-US-GuyNeural`、`zh-CN-XiaoxiaoNeural`，默认 Aria）。

响应：`audio/mpeg` 二进制流。

---

## 11. 语音转写 Speech（`/speech`）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/speech/transcribe` | 上传录音返回识别文本 |

`multipart/form-data`，字段名 `file`，支持 m4a / wav / mp3，最大 20MB。

响应：

```json
{ "text": "recognized english text" }
```

转写提供商由 `WHISPER_PROVIDER` 决定：`local`（faster-whisper，默认）/ `siliconflow` / `openai`。

---

## 12. 数据备份 Backup（`/backup`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/backup/export` | 导出全部学习数据（JSON） |
| POST | `/backup/restore` | 从导出的 JSON 恢复 |

恢复时请求体直接使用 `export` 的返回内容：

```json
{
  "chat_history": [],
  "word_progress": [],
  "reading_records": [],
  "writing_records": [],
  "daily_stats": []
}
```

---

## 13. CET 专项总览 Cet（`/cet`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/cet/dashboard` | 目标、阶段计划、今日任务总览 |
| PUT | `/cet/goal` | 设置四六级目标并生成阶段计划 |
| DELETE | `/cet/goal` | 取消目标，恢复默认计划 |

```json
{
  "exam_type": "CET4",
  "target_score": 500,
  "exam_date": "2026-12-12",
  "daily_minutes": 45
}
```

`exam_type`：`CET4` / `CET6`；`target_score` 425-710；`daily_minutes` 10-240。

---

## 14. CET 阅读（`/cet/reading`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/cet/reading/articles?exam_type=CET4` | 文章列表 |
| GET | `/cet/reading/articles/{article_id}` | 文章详情与题目（不含答案） |
| POST | `/cet/reading/submit` | 提交答案，AI 生成分析并保存 |
| GET | `/cet/reading/history?limit=` | 训练历史 |
| GET | `/cet/reading/history/{record_id}` | 记录详情（含 AI 分析） |

```json
{
  "exam_type": "CET4",
  "article_id": "cet4-2023-12-reading-1",
  "answers": [{ "question_id": "q1", "answer": "B" }]
}
```

---

## 15. CET 听力（`/cet/listening`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/cet/listening/items?exam_type=CET4` | 听力材料列表 |
| GET | `/cet/listening/items/{item_id}` | 材料详情（文本+音频+题目） |
| POST | `/cet/listening/submit` | 提交答案，AI 逐句解析 |
| GET | `/cet/listening/history?limit=` | 训练历史 |

```json
{
  "exam_type": "CET4",
  "item_id": "cet4-2023-12-listening-1",
  "answers": [{ "question_id": "q1", "answer": "A" }]
}
```

---

## 16. CET 写作（`/cet/writing`）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/cet/writing/review` | 四六级作文批改（满分 15 分） |
| GET | `/cet/writing/templates` | 我的作文模板（含 AI 推荐） |
| POST | `/cet/writing/templates` | 保存模板 |
| DELETE | `/cet/writing/templates/{template_id}` | 删除模板 |
| POST | `/cet/writing/templates/ai-recommend` | AI 生成推荐模板 |

批改请求：

```json
{
  "essay": "Your essay (10-3000 chars)...",
  "exam_type": "CET4"
}
```

保存模板：

```json
{
  "title": "议论文开头模板",
  "content": "As is vividly depicted ...",
  "category": "议论文"
}
```

AI 推荐模板：

```json
{ "exam_type": "CET4", "category": "议论文" }
```

---

## 17. CET 翻译（`/cet/translation`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/cet/translation/sentences?exam_type=CET4` | 翻译练习句子（中文） |
| POST | `/cet/translation/submit` | 提交翻译，AI 评分（词汇/语序/自然度） |
| GET | `/cet/translation/history?limit=` | 训练历史 |

```json
{
  "exam_type": "CET4",
  "sentence_id": "cet4-2023-12-translation-1",
  "chinese_text": "随着科技的发展，人们的生活方式发生了巨大变化。",
  "user_translation": "With the development of technology, people's life has changed a lot."
}
```

---

## 18. CET 口语（`/cet/speaking`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/cet/speaking/questions?exam_type=CET4` | 口语考试问题 |
| POST | `/cet/speaking/submit` | 提交口语回答（语音转写文本），AI 四维评分 |
| GET | `/cet/speaking/history?limit=` | 练习历史 |

```json
{
  "exam_type": "CET4",
  "question": "Do you prefer studying alone or with friends?",
  "user_answer": "I prefer studying alone because ..."
}
```

评分维度：流利度 / 语法 / 词汇 / 发音。

---

## 19. CET AI 教练（`/cet/coach`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/cet/coach/profile` | AI 教练画像（弱项/错误类型/历史成绩/词汇掌握） |
| GET | `/cet/coach/suggestion` | 今日 AI 学习建议（当日缓存，自动调整计划） |

---

## 附录：根端点（无需认证）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/` | 应用信息（名称/版本/状态） |
| GET | `/health` | 健康检查 |

```json
GET /health
→ { "status": "healthy" }
```
