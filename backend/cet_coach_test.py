import json
import os

TEST_DB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "coach_test.db")
if os.path.exists(TEST_DB):
    os.remove(TEST_DB)
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///" + TEST_DB.replace("\\", "/")
os.environ["SECRET_KEY"] = "coach-test-secret"
os.environ["DEBUG"] = "false"

from fastapi.testclient import TestClient
from app.main import app
import app.ai.client as ai_client_module

passed = []


def check(name, cond, extra=""):
    if cond:
        passed.append(name)
        print(f"PASS {name}")
    else:
        safe = extra.encode("ascii", "replace").decode()
        print(f"FAIL {name} {safe}")
        raise SystemExit(1)


async def fake_chat(messages, temperature=0.7, max_tokens=2000, json_mode=False, return_usage=False):
    return json.dumps({
        "summary": "今天重点强化阅读和写作。",
        "suggestions": [
            {"title": "复习 30 个核心词", "detail": "用词卡过一遍高频词", "reason": "词汇复习率 60%"},
            {"title": "阅读 2 篇", "detail": "限时训练并复盘错题", "reason": "阅读正确率偏低"},
            {"title": "修改作文高频错误", "detail": "重写上次作文的 3 处错误", "reason": "语法错误集中在时态"},
        ],
        "plan_adjustment": {"words": 30, "reading": 2, "ai_minutes": 15, "writing": 1},
    }, ensure_ascii=False)


ai_client_module.ai_client.chat = fake_chat

with TestClient(app) as client:
    r = client.post("/api/v1/auth/register", json={
        "username": "coach_user", "email": "coach@test.com", "password": "test123456"
    })
    headers = {"Authorization": f"Bearer {r.json()['access_token']}"}
    from datetime import date, timedelta
    exam = (date.today() + timedelta(days=60)).isoformat()
    client.put("/api/v1/cet/goal", json={
        "exam_type": "CET6", "target_score": 500, "exam_date": exam, "daily_minutes": 30
    }, headers=headers)

    # 1. 画像（空数据时弱项为空，结构完整）
    r = client.get("/api/v1/cet/coach/profile", headers=headers)
    p = r.json()
    check("profile structure", "weak_skills" in p and "error_types" in p
          and "exam_history" in p and "vocabulary_stats" in p and "goal" in p, str(p)[:200])
    check("goal in profile", p["goal"]["exam_type"] == "CET6" and p["goal"]["days_left"] == 60)

    # 2. 制造弱项数据：提交低分阅读
    client.post("/api/v1/cet/reading/submit", json={
        "exam_type": "CET6", "article_id": "cet6-remote",
        "answers": [{"question_id": "q1", "answer": 0}, {"question_id": "q2", "answer": 0}, {"question_id": "q3", "answer": 0}],
    }, headers=headers)

    # 3. AI 建议生成
    r = client.get("/api/v1/cet/coach/suggestion", headers=headers)
    s = r.json()
    check("suggestion generated", s["summary"] and len(s["suggestions"]) == 3, str(s)[:250])
    check("suggestion fields", all("title" in x and "detail" in x and "reason" in x for x in s["suggestions"]))

    # 4. 当日缓存（再次调用不重复请求 AI）
    ai_client_module.ai_client.chat = fake_chat
    r2 = client.get("/api/v1/cet/coach/suggestion", headers=headers)
    check("daily cached", r2.json()["summary"] == s["summary"])

    # 5. 计划已按 AI 调整
    r = client.get("/api/v1/plan/today", headers=headers)
    tasks = {t["task_type"]: t for t in r.json()["tasks"]}
    check("plan adjusted", tasks["reading"]["target_count"] == 2 and tasks["words"]["target_count"] == 30,
          str(tasks))

    # 6. AI 失败降级建议
    async def fake_fail(messages, temperature=0.7, max_tokens=2000, json_mode=False, return_usage=False):
        raise RuntimeError("ai down")

    ai_client_module.ai_client.chat = fake_fail
    import sqlite3
    conn = sqlite3.connect(TEST_DB)
    conn.execute("UPDATE cet_ai_profile SET last_suggestion_date = '2020-01-01'")
    conn.commit()
    conn.close()
    r = client.get("/api/v1/cet/coach/suggestion", headers=headers)
    s = r.json()
    check("ai fail fallback", s["summary"] and s["suggestions"]
          and s["plan_adjusted"] is False, str(s)[:200])
    check("fallback targets weak skill", any("阅读" in x["title"] for x in s["suggestions"]), str(s["suggestions"]))

print(f"\nALL {len(passed)} CHECKS PASSED")
os.remove(TEST_DB)
