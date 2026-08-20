#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""英语词库导入 / 初始化工具

支持三种数据来源：
  1. init    - 初始化内置词库（backend/data/builtin_words.csv）
  2. file    - 从本地 CSV / JSON 文件导入
  3. ecdict  - 从 ECDICT 词库下载并导入（完整词库，推荐）

支持两种写入方式：
  - API 模式：POST /api/v1/vocabulary/seed 分批写入（默认，不依赖后端环境）
  - 直连模式：直接写 SQLite 数据库（--db，无需启动后端）

用法示例：
  # 用内置词库初始化（API 模式）
  python import_words.py init --api http://192.168.1.10:8002/api/v1 --token <JWT>

  # 直连本地数据库初始化（无需后端）
  python import_words.py init --db ../english_app.db

  # 从 CSV 导入
  python import_words.py file --file words.csv --db ../english_app.db

  # 从 JSON 导入
  python import_words.py file --file words.json --api http://127.0.0.1:8002/api/v1 --token <JWT>

  # 从 ECDICT 导入 CET4（直连模式，仅入库，不落盘）
  python import_words.py ecdict --category cet4 --limit 3000 --db ../english_app.db

CSV 列（表头）：
  word,phonetic,part_of_speech,meaning,example,difficulty,category
  其中 word 必填；example 可留空或填 JSON 字符串 [{"en":"...","cn":"..."}]

JSON 格式：
  [{"word": "...", "phonetic": "...", "part_of_speech": "...",
    "meaning": "...", "example": [{"en": "...", "cn": "..."}],
    "difficulty": "medium", "category": "CET4"}, ...]
"""

import argparse
import csv
import io
import json
import sqlite3
import sys
import urllib.request
from pathlib import Path

# 词库分类 -> ECDICT tag / 默认难度
CATEGORY_TAGS = {
    "cet4": "cet4",
    "cet6": "cet6",
    "kaoyan": "ky",
    "ielts": "ielts",
    "toefl": "toefl",
}

CATEGORY_DIFFICULTY = {
    "CET4": "medium",
    "CET6": "medium",
    "KAOYAN": "medium",
    "IELTS": "hard",
    "TOEFL": "hard",
}

ECDICT_URL = "https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv"
ECDICT_HEADERS = [
    "word", "phonetic", "definition", "translation", "pos", "collins", "oxford",
    "tag", "bnc", "frq", "exchange", "detail", "audio",
]


def normalize_difficulty(value: str, category: str) -> str:
    value = (value or "").strip().lower()
    if value in ("easy", "medium", "hard"):
        return value
    if value in ("1", "2", "简单"):
        return "easy"
    if value in ("3", "中等"):
        return "medium"
    if value in ("4", "5", "困难", "难"):
        return "hard"
    return CATEGORY_DIFFICULTY.get(category.upper(), "medium")


def normalize_examples(value):
    if value is None:
        return None
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        try:
            parsed = json.loads(text)
            if isinstance(parsed, list):
                return normalize_examples(parsed)
        except Exception:
            pass
        return [{"en": text, "cn": ""}]
    if isinstance(value, list):
        result = []
        for item in value:
            if isinstance(item, dict):
                result.append({"en": str(item.get("en") or ""), "cn": str(item.get("cn") or "")})
            else:
                result.append({"en": str(item), "cn": ""})
        return result or None
    return None


def build_entry(row: dict) -> dict:
    """把外部字段统一映射为后端接受的字段"""
    word = str(row.get("word") or "").strip()
    if not word:
        return None
    category = str(row.get("category") or "CET4").strip().upper()
    meaning = row.get("meaning") or row.get("chinese_definition") or row.get("translation") or ""
    entry = {
        "word": word,
        "phonetic": row.get("phonetic") or None,
        "part_of_speech": row.get("part_of_speech") or row.get("pos") or None,
        "chinese_definition": str(meaning).strip(),
        "example_sentences": normalize_examples(
            row.get("example") if row.get("example") is not None else row.get("example_sentences")
        ),
        "difficulty": normalize_difficulty(row.get("difficulty"), category),
        "category": category,
    }
    return entry


def read_csv(path: Path) -> list[dict]:
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def read_json(path: Path) -> list[dict]:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict):
        data = data.get("words", [])
    if not isinstance(data, list):
        raise ValueError("JSON 必须是单词对象数组或 {words: [...]}")
    return data


def read_ecdict(category: str, limit: int) -> list[dict]:
    """下载 ECDICT 并按其 tag 列筛选对应分类的词"""
    print(f"下载 ECDICT 词库: {ECDICT_URL}")
    req = urllib.request.Request(ECDICT_URL, headers={"User-Agent": "english-coach-import"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        raw = resp.read().decode("utf-8", errors="ignore")

    tag = CATEGORY_TAGS.get(category, "cet4")
    rows = []
    reader = csv.DictReader(io.StringIO(raw), fieldnames=ECDICT_HEADERS)
    next(reader, None)  # 跳过表头
    for r in reader:
        word_tags = (r.get("tag") or "").lower().split()
        if tag not in word_tags:
            continue
        if not (r.get("translation") or "").strip():
            continue
        rows.append({
            "word": r["word"].strip(),
            "phonetic": (r.get("phonetic") or "").strip() or None,
            "part_of_speech": (r.get("pos") or "").strip() or None,
            "meaning": (r.get("translation") or "").strip(),
            "category": category.upper(),
            "difficulty": "medium" if category in ("cet4", "cet6", "kaoyan") else "hard",
        })
        if limit and len(rows) >= limit:
            break
    print(f"ECDICT 筛选 {category} 单词: {len(rows)} 个")
    return rows


def load_builtin() -> list[dict]:
    path = Path(__file__).parent / "builtin_words.csv"
    if not path.exists():
        raise FileNotFoundError(f"内置词库不存在: {path}")
    return read_csv(path)


def api_import(entries: list[dict], api: str, token: str, batch_size: int) -> int:
    """通过后端 /vocabulary/seed 分批导入"""
    api = api.rstrip("/")
    added = 0
    for i in range(0, len(entries), batch_size):
        batch = entries[i : i + batch_size]
        body = json.dumps({"words": batch}).encode("utf-8")
        req = urllib.request.Request(
            f"{api}/vocabulary/seed",
            data=body,
            method="POST",
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                result = json.loads(resp.read().decode("utf-8"))
            added += int(result.get("added", 0))
            print(f"  批次 {i // batch_size + 1}: 提交 {len(batch)}，新增 {result.get('added')}，共 {added}")
        except urllib.error.HTTPError as e:
            print(f"  批次失败 {e.code}: {e.read().decode('utf-8', errors='ignore')[:300]}", file=sys.stderr)
            raise
    return added


def db_import(entries: list[dict], db_path: str, batch_size: int, update_category: bool = False) -> int:
    """直连 SQLite 导入（INSERT OR IGNORE，按 word 去重）"""
    con = sqlite3.connect(db_path)
    cur = con.cursor()
    added = 0
    updated = 0
    try:
        for i in range(0, len(entries), batch_size):
            batch = entries[i : i + batch_size]
            for e in batch:
                example_json = json.dumps(e["example_sentences"], ensure_ascii=False) if e["example_sentences"] else None
                cur.execute(
                    """INSERT OR IGNORE INTO vocabulary_words
                       (id, word, phonetic, part_of_speech, chinese_definition,
                        example_sentences, difficulty, category, created_at)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))""",
                    (
                        str(uuid4()),
                        e["word"],
                        e["phonetic"],
                        e["part_of_speech"],
                        e["chinese_definition"],
                        example_json,
                        e["difficulty"].upper(),
                        e["category"],
                    ),
                )
                added += cur.rowcount
                if update_category:
                    cur.execute(
                        "UPDATE vocabulary_words SET category = ? WHERE word = ? AND category != ?",
                        (e["category"], e["word"], e["category"]),
                    )
                    updated += cur.rowcount
            con.commit()
            print(f"  批次 {i // batch_size + 1}: 提交 {len(batch)}，累计新增 {added}，重标 {updated}")
    finally:
        con.close()
    return added


def uuid4() -> str:
    import uuid
    return str(uuid.uuid4())


def main():
    parser = argparse.ArgumentParser(description="英语词库导入 / 初始化工具")
    sub = parser.add_subparsers(dest="mode", required=True)

    for name in ("init", "file", "ecdict"):
        p = sub.add_parser(name)
        if name == "file":
            p.add_argument("--file", required=True, help="CSV 或 JSON 文件路径")
        if name == "ecdict":
            p.add_argument("--category", default="cet4", choices=list(CATEGORY_TAGS.keys()), help="目标分类")
            p.add_argument("--limit", type=int, default=0, help="导入上限（0 为全部）")
        p.add_argument("--db", default=None, help="SQLite 数据库路径（直连模式），缺省使用 API 模式")
        p.add_argument("--api", default=None, help="后端 API 基础地址，如 http://127.0.0.1:8002/api/v1")
        p.add_argument("--token", default=None, help="JWT token（API 模式必填）")
        p.add_argument("--batch-size", type=int, default=50, help="每批导入数量")
        p.add_argument("--dry-run", action="store_true", help="只解析不写入")
        p.add_argument("--update-category", action="store_true", help="已存在的单词重标为本次导入的分类（仅直连模式）")

    args = parser.parse_args()

    if args.mode == "init":
        entries = [build_entry(r) for r in load_builtin()]
    elif args.mode == "file":
        path = Path(args.file)
        if path.suffix.lower() == ".json":
            entries = [build_entry(r) for r in read_json(path)]
        else:
            entries = [build_entry(r) for r in read_csv(path)]
    else:
        entries = read_ecdict(args.category, args.limit)

    entries = [e for e in entries if e]
    print(f"解析完成，共 {len(entries)} 个单词")
    if not entries:
        print("没有可导入的单词，退出")
        return

    if args.dry_run:
        print("dry-run：不写入")
        return

    if args.db:
        added = db_import(entries, args.db, args.batch_size, args.update_category)
    else:
        if not args.api:
            print("请提供 --db 或 --api/--token（API 模式需要 token）", file=sys.stderr)
            sys.exit(1)
        added = api_import(entries, args.api, args.token or "", args.batch_size)

    print(f"完成：共 {len(entries)} 个，新增 {added} 个，跳过 {len(entries) - added} 个（已存在）")


if __name__ == "__main__":
    main()
