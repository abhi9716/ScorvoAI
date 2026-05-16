from datetime import date, datetime, timedelta
from models.db import get_db

def save_result(score: int, total: int, topic: str = "general") -> dict:
    with get_db() as conn:
        cursor = conn.execute(
            "INSERT INTO results (score, total, timestamp, topic) VALUES (?, ?, ?, ?)",
            (score, total, datetime.now().isoformat(), topic)
        )
        return {"id": cursor.lastrowid, "score": score, "total": total}

def save_daily_result(score: int, total: int) -> dict:
    today = date.today().isoformat()
    with get_db() as conn:
        cursor = conn.execute(
            "INSERT INTO daily_results (score, total, timestamp, date) VALUES (?, ?, ?, ?)",
            (score, total, datetime.now().isoformat(), today)
        )
        return {"id": cursor.lastrowid, "score": score, "total": total, "date": today}

def get_stats() -> dict:
    with get_db() as conn:
        row = conn.execute("SELECT COUNT(*) as total, COALESCE(AVG(CAST(score AS FLOAT) / total * 100), 0) as avg_score FROM results").fetchone()
        total_quizzes = row["total"]
        avg_score = round(row["avg_score"], 1)

        best = conn.execute("SELECT MAX(CAST(score AS FLOAT) / total * 100) as best FROM results").fetchone()
        best_score = round(best["best"], 1) if best["best"] else 0

        last_20 = conn.execute("SELECT CAST(score AS FLOAT) / total * 100 as pct FROM results ORDER BY timestamp DESC LIMIT 20").fetchall()
        recent_scores = [round(r["pct"], 1) for r in last_20][::-1]

        daily_trend = conn.execute("""
            SELECT date(timestamp) as day, COUNT(*) as count, AVG(CAST(score AS FLOAT) / total * 100) as avg
            FROM results
            WHERE date(timestamp) >= date('now', '-30 days')
            GROUP BY date(timestamp)
            ORDER BY day
        """).fetchall()
        trend = [{"date": r["day"], "quizzes": r["count"], "avg_score": round(r["avg"], 1)} for r in daily_trend]

        subject_split = conn.execute("""
            SELECT topic, COUNT(*) as count, AVG(CAST(score AS FLOAT) / total * 100) as avg
            FROM results
            GROUP BY topic
            ORDER BY count DESC
        """).fetchall()
        subjects = [{"name": r["topic"], "count": r["count"], "avg": round(r["avg"], 1)} for r in subject_split]

        score_ranges = {"0-25": 0, "26-50": 0, "51-75": 0, "76-100": 0}
        all_pcts = conn.execute("SELECT CAST(score AS FLOAT) / total * 100 as pct FROM results").fetchall()
        for r in all_pcts:
            p = r["pct"]
            if p <= 25: score_ranges["0-25"] += 1
            elif p <= 50: score_ranges["26-50"] += 1
            elif p <= 75: score_ranges["51-75"] += 1
            else: score_ranges["76-100"] += 1

        total_daily = conn.execute("SELECT COUNT(*) as c FROM daily_results").fetchone()["c"]
        daily_avg_row = conn.execute("SELECT AVG(CAST(score AS FLOAT) / total * 100) as avg FROM daily_results").fetchone()
        daily_avg = round(daily_avg_row["avg"], 1) if daily_avg_row["avg"] else 0

        return {
            "total_quizzes": total_quizzes,
            "average_score_percent": avg_score,
            "best_score_percent": best_score,
            "recent_scores": recent_scores,
            "daily_trend": trend,
            "subject_split": subjects,
            "score_distribution": score_ranges,
            "total_daily_challenges": total_daily,
            "daily_avg_score": daily_avg,
        }

def get_analyze() -> dict:
    with get_db() as conn:
        rows = conn.execute("SELECT topic, COUNT(*) as attempts, AVG(CAST(score AS FLOAT) / total * 100) as avg FROM results GROUP BY topic ORDER BY avg ASC").fetchall()
        weak_topics = [{"topic": r["topic"], "attempts": r["attempts"], "avg_score": round(r["avg"], 1)} for r in rows if r["avg"] < 60]
        strong_topics = [{"topic": r["topic"], "attempts": r["attempts"], "avg_score": round(r["avg"], 1)} for r in rows if r["avg"] >= 60]

        chapter_perf = conn.execute("""
            SELECT topic, AVG(CAST(score AS FLOAT) / total * 100) as avg, COUNT(*) as attempts
            FROM results
            GROUP BY topic
            ORDER BY avg DESC
        """).fetchall()
        chapter_breakdown = [{"name": r["topic"], "avg": round(r["avg"], 1), "attempts": r["attempts"]} for r in chapter_perf]

        improvement = conn.execute("""
            SELECT rowid, CAST(score AS FLOAT) / total * 100 as pct, timestamp
            FROM results ORDER BY timestamp
        """).fetchall()
        improvement_trend = []
        window = 5
        for i in range(len(improvement)):
            start = max(0, i - window + 1)
            window_scores = [improvement[j]["pct"] for j in range(start, i + 1)]
            improvement_trend.append(round(sum(window_scores) / len(window_scores), 1))

        subject_details = conn.execute("""
            SELECT topic,
                COUNT(*) as attempts,
                AVG(CAST(score AS FLOAT) / total * 100) as avg,
                MAX(CAST(score AS FLOAT) / total * 100) as best,
                MIN(CAST(score AS FLOAT) / total * 100) as worst,
                SUM(CASE WHEN CAST(score AS FLOAT) / total * 100 >= 60 THEN 1 ELSE 0 END) as passes
            FROM results
            GROUP BY topic
        """).fetchall()
        subject_details_list = [{
            "name": r["topic"],
            "attempts": r["attempts"],
            "avg": round(r["avg"], 1),
            "best": round(r["best"], 1),
            "worst": round(r["worst"], 1),
            "pass_rate": round(r["passes"] / r["attempts"] * 100, 1) if r["attempts"] > 0 else 0,
        } for r in subject_details]

        suggestions = []
        for wt in weak_topics:
            suggestions.append(f"Focus more on {wt['topic']} - your average is {wt['avg_score']}%. Practice daily.")
        if not weak_topics:
            suggestions.append("You are doing well across all topics. Keep practicing to improve speed.")

        overall_consistency = 0
        if len(recent_scores := [r["avg"] for r in chapter_perf]):
            mean_val = sum(recent_scores) / len(recent_scores)
            variance = sum((x - mean_val) ** 2 for x in recent_scores) / len(recent_scores)
            std_dev = variance ** 0.5
            overall_consistency = round(max(0, 100 - std_dev * 3), 1)

        return {
            "weak_topics": weak_topics,
            "strong_topics": strong_topics,
            "chapter_breakdown": chapter_breakdown,
            "improvement_trend": improvement_trend,
            "subject_details": subject_details_list,
            "suggestions": suggestions,
            "consistency_score": overall_consistency,
        }
