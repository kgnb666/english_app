# core/schema.py - 轻量级启动迁移：为已存在的表补齐新列（不丢数据）

import logging

from sqlalchemy import text

logger = logging.getLogger("app.schema")

# (列名, 补齐语句)
DAILY_STATS_MIGRATIONS = [
    ("study_seconds", "ALTER TABLE daily_stats ADD COLUMN study_seconds INTEGER NOT NULL DEFAULT 0"),
    ("ai_minutes", "ALTER TABLE daily_stats ADD COLUMN ai_minutes INTEGER NOT NULL DEFAULT 0"),
    ("reading_count", "ALTER TABLE daily_stats ADD COLUMN reading_count INTEGER NOT NULL DEFAULT 0"),
    ("writing_count", "ALTER TABLE daily_stats ADD COLUMN writing_count INTEGER NOT NULL DEFAULT 0"),
]

# (表名, 列名, 补齐语句)
WORD_PROGRESS_MIGRATIONS = [
    ("ease_factor", "ALTER TABLE user_word_progress ADD COLUMN ease_factor FLOAT NOT NULL DEFAULT 2.5"),
    ("repetition", "ALTER TABLE user_word_progress ADD COLUMN repetition INTEGER NOT NULL DEFAULT 0"),
    ("error_count", "ALTER TABLE user_word_progress ADD COLUMN error_count INTEGER NOT NULL DEFAULT 0"),
    ("is_bookmarked", "ALTER TABLE user_word_progress ADD COLUMN is_bookmarked BOOLEAN NOT NULL DEFAULT 0"),
]

# vocabulary_words 新列
WORD_MIGRATIONS = [
    ("audio_url", "ALTER TABLE vocabulary_words ADD COLUMN audio_url VARCHAR(500)"),
    ("exam_type", "ALTER TABLE vocabulary_words ADD COLUMN exam_type VARCHAR(10)"),
    ("word_level", "ALTER TABLE vocabulary_words ADD COLUMN word_level VARCHAR(20)"),
]

# writing_records 新列
WRITING_MIGRATIONS = [
    ("exam_type", "ALTER TABLE writing_records ADD COLUMN exam_type VARCHAR(10)"),
]


async def ensure_schema(conn) -> None:
    """create_all 之后调用：检查并补齐 daily_stats 新列，回填秒数"""
    result = await conn.execute(text("PRAGMA table_info(daily_stats)"))
    cols = {row[1] for row in result.fetchall()}
    for col, stmt in DAILY_STATS_MIGRATIONS:
        if col not in cols:
            await conn.execute(text(stmt))
            logger.info("Migrated daily_stats: added column %s", col)
    # 旧数据回填：study_minutes -> study_seconds（保持两者一致）
    await conn.execute(
        text(
            "UPDATE daily_stats "
            "SET study_seconds = study_minutes * 60 "
            "WHERE study_seconds = 0 AND study_minutes > 0"
        )
    )
    # user_word_progress 新列
    result = await conn.execute(text("PRAGMA table_info(user_word_progress)"))
    cols = {row[1] for row in result.fetchall()}
    for col, stmt in WORD_PROGRESS_MIGRATIONS:
        if col not in cols:
            await conn.execute(text(stmt))
            logger.info("Migrated user_word_progress: added column %s", col)
    # vocabulary_words 新列
    result = await conn.execute(text("PRAGMA table_info(vocabulary_words)"))
    cols = {row[1] for row in result.fetchall()}
    for col, stmt in WORD_MIGRATIONS:
        if col not in cols:
            await conn.execute(text(stmt))
            logger.info("Migrated vocabulary_words: added column %s", col)
    # 回填 exam_type（从 category 推断）与 word_level 默认值
    await conn.execute(
        text(
            "UPDATE vocabulary_words "
            "SET exam_type = CASE "
            "  WHEN category LIKE '%CET6%' OR category LIKE '%6%' THEN 'CET6' "
            "  ELSE 'CET4' END "
            "WHERE exam_type IS NULL OR exam_type = ''"
        )
    )
    await conn.execute(
        text(
            "UPDATE vocabulary_words SET word_level = 'core' "
            "WHERE word_level IS NULL OR word_level = ''"
        )
    )
    # writing_records 新列
    result = await conn.execute(text("PRAGMA table_info(writing_records)"))
    cols = {row[1] for row in result.fetchall()}
    for col, stmt in WRITING_MIGRATIONS:
        if col not in cols:
            await conn.execute(text(stmt))
            logger.info("Migrated writing_records: added column %s", col)
