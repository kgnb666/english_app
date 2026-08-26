# 数据库结构说明

后端使用 SQLite（默认 `backend/english_app.db`），通过 SQLAlchemy 2 异步 ORM 管理。应用启动时调用 `Base.metadata.create_all` 自动建表，当前共 **26 张表**，无需手工迁移。

## 约定

- 主键：全部为 `VARCHAR(36)` 的 UUID4 字符串
- 用户关联：所有业务表都带 `user_id` 外键（指向 `users.id`）并建索引
- 时间字段：统一 `DATETIME`，默认 `datetime.utcnow`
- JSON 字段：SQLite 中以文本存储，SQLAlchemy `JSON` 类型自动序列化
- 枚举字段：`VARCHAR` + Python Enum（SQLAlchemy `Enum` 类型）

## 表总览

| 分组 | 表 |
|------|-----|
| 用户与认证 | `users`、`refresh_tokens` |
| 对话 | `chat_sessions`、`chat_messages` |
| 单词 | `vocabulary_words`、`user_word_progress`、`word_examples`、`word_book` |
| 学习行为 | `daily_stats`、`study_sessions`、`test_records` |
| 计划 | `learning_plan`、`daily_tasks` |
| 阅读/作文 | `reading_records`、`writing_records` |
| 画像 | `user_profile`、`user_error_log`、`pronunciation_records` |
| CET 目标 | `cet_goals`、`cet_study_plan`、`cet_ai_profile` |
| CET 训练 | `cet_reading_records`、`cet_listening_records`、`cet_speaking_records`、`cet_translation` |
| CET 写作 | `writing_templates` |

## 1. 用户与认证

### users — 用户表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 用户 ID（UUID） |
| username | VARCHAR(50) UNIQUE | 用户名 |
| email | VARCHAR(100) UNIQUE | 邮箱 |
| password_hash | VARCHAR(255) | bcrypt 密码哈希 |
| english_level | Enum | `beginner` / `elementary` / `intermediate` / `upper_intermediate` / `advanced`，默认 beginner |
| daily_goal_minutes | Integer | 每日学习分钟目标，默认 30 |
| daily_goal_words | Integer | 每日单词目标，默认 20 |
| streak_days | Integer | 连续学习天数 |
| last_study_date | Date | 最近学习日期（用于计算连续天数） |
| avatar_url | VARCHAR(500) | 头像地址 |
| created_at | DateTime | 创建时间 |

### refresh_tokens — 刷新令牌表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 所属用户 |
| token_hash | VARCHAR(128) UNIQUE | refresh token 的 sha256 哈希（不存明文） |
| expires_at | DateTime | 过期时间（默认 5 天） |
| revoked | Boolean | 是否已注销（退出登录/轮换时置 true） |
| created_at | DateTime | 创建时间 |

## 2. 对话

### chat_sessions — AI 对话会话

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 会话 ID |
| user_id | VARCHAR(36) FK | 所属用户 |
| title | VARCHAR(200) | 会话标题，默认 "New Conversation" |
| topic | VARCHAR(100) | 会话主题（可为空） |
| message_count | Integer | 消息数 |
| created_at / updated_at | DateTime | 创建/更新时间 |

### chat_messages — 对话消息

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 消息 ID |
| session_id | VARCHAR(36) FK | 所属会话 |
| role | Enum | `user` / `assistant` / `system` |
| content | Text | 消息内容 |
| grammar_corrections | JSON | 语法纠错：`{original, corrected, explanation}` |
| created_at | DateTime | 创建时间 |

## 3. 单词

### vocabulary_words — 词库

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 单词 ID |
| word | VARCHAR(100) UNIQUE | 单词本身（唯一） |
| phonetic | VARCHAR(100) | 音标 |
| part_of_speech | VARCHAR(20) | 词性（v./n./adj.…） |
| chinese_definition | Text | 中文释义（必填） |
| example_sentences | JSON | 例句数组 `[{en, cn}]` |
| difficulty | Enum | `easy` / `medium` / `hard`，默认 medium |
| category | VARCHAR(50) | 分类：CET4 / CET6 / IELTS / TOEFL 等 |
| exam_type | VARCHAR(10) | CET4 / CET6 |
| word_level | VARCHAR(20) | `core` / `high_freq` / `rare_meaning` / `error_prone` |
| audio_url | VARCHAR(500) | 固定音频资源地址 |
| created_at | DateTime | 创建时间 |

### user_word_progress — 用户单词学习进度

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 进度 ID |
| user_id | VARCHAR(36) FK | 用户 |
| word_id | VARCHAR(36) FK | 单词 |
| status | Enum | `new` / `learning` / `review` / `mastered`，默认 new |
| review_count | Integer | 复习次数 |
| repetition | Integer | SM-2 连续答对次数 |
| ease_factor | Float | SM-2 难度系数，默认 2.5 |
| error_count | Integer | 累计错误次数 |
| is_bookmarked | Boolean | 是否加入生词本 |
| next_review_date | Date | 下次复习日期（SM-2 计算） |
| last_review_date | Date | 最近复习日期 |
| memory_aid | Text | AI 生成的记忆方法 |
| created_at | DateTime | 创建时间 |

### word_examples — 四六级真题例句

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| word_id | VARCHAR(36) FK | 所属单词 |
| example | Text | 真题句子 |
| translation_cn | Text | 中文翻译 |
| source | VARCHAR(30) | 来源，如 `CET4-2023-12` |
| created_at | DateTime | 创建时间 |

### word_book — 生词本

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| word_id | VARCHAR(36) FK | 单词 |
| source | VARCHAR(20) | `manual` / `reading` / `chat`，默认 manual |
| source_context | Text | 来源上下文（如阅读中的原句） |
| created_at | DateTime | 收藏时间 |

唯一约束：`(user_id, word_id)`。

## 4. 学习行为

### daily_stats — 每日学习统计

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| date | Date | 统计日期 |
| study_minutes | Integer | 学习分钟 |
| study_seconds | Integer | 学习秒数（真实计时） |
| words_learned | Integer | 新学单词数 |
| words_reviewed | Integer | 复习单词数 |
| chat_messages | Integer | 对话消息数 |
| ai_minutes | Integer | AI 学习分钟 |
| reading_count | Integer | 阅读次数 |
| writing_count | Integer | 作文批改次数 |
| created_at | DateTime | 创建时间 |

### study_sessions — 真实学习计时会话

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 会话 ID |
| user_id | VARCHAR(36) FK | 用户 |
| session_type | VARCHAR(20) | `chat` / `words` / `reading` / `writing` |
| started_at | DateTime | 开始时间 |
| ended_at | DateTime | 结束时间（可空） |
| duration_seconds | Integer | 实际时长（秒，可空） |
| status | VARCHAR(20) | `active` / `completed` |
| created_at | DateTime | 创建时间 |

### test_records — 单词测验记录

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| test_type | VARCHAR(20) | `choice` / `spelling` / `listening` |
| score | Integer | 答对数 |
| total | Integer | 总题数 |
| results | JSON | 每题作答明细 |
| created_at | DateTime | 创建时间 |

## 5. 计划

### learning_plan — 学习计划模板

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| task_type | VARCHAR(20) | `words` / `ai_minutes` / `reading` / `writing` |
| target_count | Integer | 目标数量/分钟 |
| enabled | Boolean | 是否启用 |
| created_at / updated_at | DateTime | 创建/更新时间 |

唯一约束：`(user_id, task_type)`。

### daily_tasks — 每日任务

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| task_date | Date | 任务日期 |
| task_type | VARCHAR(20) | 任务类型 |
| target_count | Integer | 目标值 |
| completed_count | Integer | 已完成值（来自真实学习数据） |
| status | VARCHAR(20) | `pending` / `completed` |
| created_at / updated_at | DateTime | 创建/更新时间 |

唯一约束：`(user_id, task_date, task_type)`。

## 6. 阅读与作文历史

### reading_records — 阅读分析记录

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| article_content | Text | 原文（前 3000 字符） |
| analysis_result | JSON | AI 分析结果 |
| created_at | DateTime | 创建时间 |

### writing_records — 作文批改记录

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| exam_type | VARCHAR(10) | CET4 / CET6（四六级作文训练使用，可空） |
| original_text | Text | 原文（前 3000 字符） |
| score | Integer | 得分（可空） |
| correction_result | JSON | AI 批改结果 |
| created_at | DateTime | 创建时间 |

## 7. 用户画像

### user_profile — 学习画像

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK UNIQUE | 用户（一人一条） |
| english_level | VARCHAR(20) | 英语等级，默认 beginner |
| goal | Text | 学习目标 |
| vocabulary_size | Integer | 词汇量估计 |
| weak_skills | JSON | 薄弱技能数组 |
| preferences | JSON | 学习偏好 `{focus, topics, style}` |
| created_at / updated_at | DateTime | 创建/更新时间 |

### user_error_log — 错误记录

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| wrong_text | Text | 用户错误句子 |
| correct_text | Text | 正确表达 |
| error_type | VARCHAR(50) | 错误类型（如 `past_tense`），默认 other |
| error_type_cn | VARCHAR(50) | 错误类型中文，默认 其他错误 |
| count | Integer | 出现次数（相同错误累加） |
| last_seen_at | DateTime | 最近出现时间 |
| created_at | DateTime | 创建时间 |

唯一约束：`(user_id, wrong_text, error_type)`。

### pronunciation_records — 发音评测记录

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| target_text | Text | 目标句子 |
| recognized_text | Text | 语音识别结果 |
| score | Integer | 发音评分 0-100 |
| result | JSON | `{mispronounced_words, suggestions, overall_advice}` |
| created_at | DateTime | 创建时间 |

## 8. CET 目标与计划

### cet_goals — 四六级考试目标

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK UNIQUE | 用户（一人一个目标） |
| exam_type | VARCHAR(10) | CET4 / CET6 |
| target_score | Integer | 目标分数，默认 425 |
| exam_date | Date | 考试日期 |
| daily_minutes | Integer | 每日学习分钟，默认 30 |
| created_at / updated_at | DateTime | 创建/更新时间 |

### cet_study_plan — 四六级阶段计划

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| goal_id | VARCHAR(36) FK | 关联 cet_goals |
| phase | Integer | 阶段序号 1-4 |
| phase_name | VARCHAR(50) | 阶段名称 |
| focus | VARCHAR(100) | 阶段重点 |
| start_date / end_date | Date | 阶段起止日期 |
| daily_words | Integer | 每日单词数 |
| daily_reading | Integer | 每日阅读篇数 |
| daily_listening_minutes | Integer | 每日听力分钟 |
| daily_writing_minutes | Integer | 每日写作分钟 |
| status | VARCHAR(20) | `done` / `active` / `upcoming` |
| created_at | DateTime | 创建时间 |

### cet_ai_profile — AI 教练画像

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK UNIQUE | 用户 |
| weak_skills | JSON | 弱项数组 |
| error_types | JSON | 错误类型聚合 |
| exam_history | JSON | 历史成绩 |
| vocabulary_stats | JSON | 词汇掌握统计 |
| last_suggestion | JSON | 最近一次 AI 建议 |
| last_suggestion_date | Date | 建议生成日期（当日缓存） |
| created_at / updated_at | DateTime | 创建/更新时间 |

## 9. CET 训练记录

### cet_reading_records — CET 阅读训练

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| exam_type | VARCHAR(10) | CET4 / CET6 |
| article_id | VARCHAR(40) | 文章 ID |
| title | VARCHAR(200) | 文章标题 |
| article | Text | 文章全文 |
| questions | JSON | 题目 |
| user_answers | JSON | 用户答案 |
| score / total | Integer | 得分/总分 |
| analysis | JSON | AI 分析（每题原因/陷阱、长难句、生词） |
| created_at | DateTime | 创建时间 |

### cet_listening_records — CET 听力训练

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| exam_type | VARCHAR(10) | CET4 / CET6 |
| item_id | VARCHAR(40) | 材料 ID |
| title | VARCHAR(200) | 材料标题 |
| audio_url | VARCHAR(500) | 音频地址（可空） |
| script | Text | 听力原文 |
| questions | JSON | 题目 |
| user_answers | JSON | 用户答案 |
| score / total | Integer | 得分/总分 |
| analysis | JSON | AI 逐句解析 + 生词解释 |
| created_at | DateTime | 创建时间 |

### cet_speaking_records — CET 口语模拟

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| exam_type | VARCHAR(10) | CET4 / CET6 |
| question | Text | 题目 |
| user_answer | Text | 用户回答 |
| audio_url | VARCHAR(500) | 录音地址（可空） |
| score | Integer | 总分 |
| scores | JSON | 四维评分（流利度/语法/词汇/发音） |
| analysis | JSON | AI 分析与建议 |
| created_at | DateTime | 创建时间 |

### cet_translation — CET 翻译训练

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| exam_type | VARCHAR(10) | CET4 / CET6 |
| chinese_text | Text | 中文原文 |
| user_translation | Text | 用户译文 |
| score | Integer | 得分 |
| analysis | JSON | AI 分析（词汇/语序/自然度/参考译文） |
| created_at | DateTime | 创建时间 |

## 10. CET 作文模板

### writing_templates — 个人作文模板库

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | 记录 ID |
| user_id | VARCHAR(36) FK | 用户 |
| title | VARCHAR(100) | 模板标题 |
| content | Text | 模板内容 |
| category | VARCHAR(50) | 分类：议论文 / 书信 / 图表等 |
| is_ai_recommended | Boolean | 是否 AI 推荐生成 |
| created_at | DateTime | 创建时间 |

## 常见操作

```sql
-- 查看全部表
SELECT name FROM sqlite_master WHERE type='table';

-- 查看某表结构
PRAGMA table_info(daily_stats);

-- 统计用户数
SELECT COUNT(*) FROM users;
```

> 注意：表结构由代码中的模型定义，修改模型后重启应用会自动为缺失的表建表，但不会自动迁移已有表的列变更。生产环境建议引入 Alembic 迁移（`backend/alembic/` 已预留目录）。
