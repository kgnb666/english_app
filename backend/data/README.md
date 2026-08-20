# 英语词库导入工具

`import_words.py` 支持将 CET4 / CET6 / 考研 / IELTS / TOEFL 词库批量导入，
数据源支持内置词库、本地 CSV / JSON 文件、ECDICT 在线词库。

## 快速初始化（推荐）

先启动后端并登录拿到 JWT token，然后：

```bash
# 方式一：通过后端 API 导入（逐批写入 /api/v1/vocabulary/seed）
python import_words.py init --api http://127.0.0.1:8002/api/v1 --token <JWT>

# 方式二：直连 SQLite 数据库（无需启动后端）
python import_words.py init --db ../english_app.db
```

内置词库 `builtin_words.csv` 含 5 个分类约 2500 个常用单词
（含音标、词性、中文释义、难度），重复导入会自动跳过已存在的单词，
不影响任何用户学习记录。

## 从 CSV / JSON 导入

CSV 表头：`word,phonetic,part_of_speech,meaning,example,difficulty,category`

```bash
python import_words.py file --file words.csv --db ../english_app.db
python import_words.py file --file words.json --api http://127.0.0.1:8002/api/v1 --token <JWT>
```

JSON 格式：

```json
[
  {
    "word": "abandon",
    "phonetic": "/əˈbændən/",
    "part_of_speech": "v.",
    "meaning": "放弃；抛弃",
    "example": [{"en": "He abandoned his plan.", "cn": "他放弃了计划。"}],
    "difficulty": "medium",
    "category": "CET4"
  }
]
```

字段兼容旧命名：`meaning` / `chinese_definition` / `translation` 均可；
`example` / `example_sentences` 均可（支持 JSON 字符串或数组）。

## 从 ECDICT 导入完整词库

```bash
# 下载 ECDICT（约 460k 词）并按 tag 筛选 CET4，直连数据库入库
python import_words.py ecdict --category cet4 --limit 3000 --db ../english_app.db
# 支持分类：cet4 / cet6 / kaoyan / ielts / toefl
```

> ECDICT 数据版权归原作者 skywind3000 所有，仅用于学习研究。

## 其他参数

- `--batch-size 50`：每批导入数量（API 模式默认 50）
- `--dry-run`：只解析不写入
- `--update-category`：直连模式下，已存在的单词重标为本次导入的分类
  （用于单独补充某个词表时让分类更准确）
