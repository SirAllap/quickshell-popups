#!/usr/bin/env python3
"""Outputs clean JSON for ClaudePopup.qml.
Reads from /tmp/waybar_claude_usage.json and /tmp/waybar_claude_tokens.json"""
import json, re, time
from datetime import datetime, timedelta
from pathlib import Path

CACHE_FILE   = Path("/tmp/waybar_claude_usage.json")
TOKEN_CACHE  = Path("/tmp/waybar_claude_tokens.json")
LOCK_FILE    = Path("/tmp/waybar_claude_fetch.lock")
FETCH_SCRIPT = Path.home() / ".config/waybar/scripts/waybar-claude-fetch.py"

_MODEL_PRICING = {
    "claude-opus-4-6":           (15.0,  75.0, 1.875,  18.75),
    "claude-sonnet-4-6":         ( 3.0,  15.0, 0.30,    3.75),
    "claude-haiku-4-5-20251001": ( 0.80,  4.0, 0.08,    1.00),
}

def short_model(m):
    if "opus"    in m: return "Opus"
    if "sonnet"  in m: return "Sonnet"
    if "haiku"   in m: return "Haiku"
    return m[:7]

def fmt_tokens(n):
    if n < 1000:       return str(n)
    if n < 1_000_000:  return f"{n/1000:.1f}K"
    return f"{n/1_000_000:.1f}M"

def fmt_ms(ms):
    s = int(ms / 1000)
    if s >= 60:
        m, s2 = divmod(s, 60)
        return f"{m}m{s2}s"
    return f"{s}s"

def reset_compact(reset_str):
    if not reset_str: return ""
    clean = re.sub(r'\s*\(.*\)', '', reset_str).strip()
    m = re.match(r'^(\d+)\s*h\s*(\d+)\s*m$', clean, re.IGNORECASE)
    if m: return f"{m.group(1)}h{m.group(2)}m"
    m = re.match(r'^(\d+)\s*h$', clean, re.IGNORECASE)
    if m: return f"{m.group(1)}h"
    try:
        tz_match = re.search(r'\(([^)]+)\)', reset_str)
        from zoneinfo import ZoneInfo
        tz = ZoneInfo(tz_match.group(1) if tz_match else "UTC")
        now = datetime.now(tz)
        repaired = re.sub(r'(\d+)\s+([ap])\s*m$', r'\1\2m', clean, re.IGNORECASE)
        repaired = re.sub(r'^(\d+)\s+m$', r'\1am', repaired)
        up = repaired.upper()
        for fmt in ["%b %d, %I:%M%p", "%b %d, %I%p", "%I:%M%p", "%I%p"]:
            try:
                if fmt in ("%I%p", "%I:%M%p"):
                    dt = datetime.strptime(f"{up} {now.year}-{now.month:02d}-{now.day:02d}", f"{fmt} %Y-%m-%d")
                else:
                    dt = datetime.strptime(f"{up} {now.year}", f"{fmt} %Y")
                dt = dt.replace(tzinfo=tz)
                if dt <= now: dt += timedelta(days=1)
                total = max(0, int((dt - now).total_seconds() / 60))
                h, m2 = divmod(total, 60)
                return f"{h}h{m2}m" if m2 else (f"{h}h" if h else f"{m2}m")
            except ValueError:
                continue
    except Exception:
        pass
    return ""

def usage_color(pct):
    if pct >= 90: return "#f38ba8"   # red
    if pct >= 75: return "#eba0ac"   # maroon
    if pct >= 50: return "#f9e2af"   # yellow
    return "#a6e3a1"                  # green

def budget_info(section):
    if not section: return None
    reset_str = section.get("resetTime", "")
    if not reset_str: return None
    try:
        tz_match = re.search(r'\(([^)]+)\)', reset_str)
        from zoneinfo import ZoneInfo
        tz = ZoneInfo(tz_match.group(1) if tz_match else "UTC")
        now = datetime.now(tz)
        # find reset dt
        clean = re.sub(r'\s*\(.*\)', '', reset_str).strip()
        repaired = re.sub(r'(\d+)\s+([ap])\s*m$', r'\1\2m', clean, re.IGNORECASE)
        repaired = re.sub(r'^(\d+)\s+m$', r'\1am', repaired)
        up = repaired.upper()
        reset_dt = None
        for fmt in ["%b %d, %I:%M%p", "%b %d, %I%p", "%I:%M%p", "%I%p"]:
            try:
                if fmt in ("%I%p", "%I:%M%p"):
                    dt = datetime.strptime(f"{up} {now.year}-{now.month:02d}-{now.day:02d}", f"{fmt} %Y-%m-%d")
                else:
                    dt = datetime.strptime(f"{up} {now.year}", f"{fmt} %Y")
                dt = dt.replace(tzinfo=tz)
                if dt <= now: dt += timedelta(days=1)
                reset_dt = dt
                break
            except ValueError:
                continue
        if reset_dt is None: return None
        cycle_start = reset_dt - timedelta(days=7)
        current_day = max(1, min(7, (now.date() - cycle_start.date()).days + 1))
        cumulative_budget = (100.0 / 7) * current_day
        actual_pct = section.get("percent", 0)
        ratio = (actual_pct / cumulative_budget * 100) if cumulative_budget > 0 else 0
        return {"day": current_day, "budget_pct": round(cumulative_budget), "ratio": round(ratio), "color": usage_color(round(ratio))}
    except Exception:
        return None

try:
    raw = json.loads(CACHE_FILE.read_text()) if CACHE_FILE.exists() else None
    tok = json.loads(TOKEN_CACHE.read_text()) if TOKEN_CACHE.exists() else None

    fetching = LOCK_FILE.exists()
    age = int(time.time() - (raw.get("timestamp", 0) / 1000)) if raw else 0

    def section(key):
        if not raw: return {"percent": 0, "reset": "", "color": "#6c7086"}
        s = raw.get(key)
        if not s: return {"percent": 0, "reset": "", "color": "#6c7086"}
        pct = s.get("percent", 0)
        return {"percent": pct, "reset": reset_compact(s.get("resetTime", "")), "color": usage_color(pct)}

    sess = section("session")
    week = section("week")
    week_s = section("weekSonnet")
    extra_raw = raw.get("extra") if raw else None
    extra = {
        "percent": extra_raw.get("percent", 0) if extra_raw else 0,
        "spent": extra_raw.get("spent", 0.0) if extra_raw else 0.0,
        "limit": extra_raw.get("limit", 0.0) if extra_raw else 0.0,
        "color": usage_color(extra_raw.get("percent", 0)) if extra_raw else "#6c7086"
    } if extra_raw else None

    week_budget  = budget_info(raw.get("week") if raw else None)
    wson_budget  = budget_info(raw.get("weekSonnet") if raw else None)

    # Token/model stats
    today = {}
    if tok and tok.get("message_count", 0) > 0:
        models_raw = tok.get("models", {})
        models = []
        costs = {}
        total_cost = 0.0
        for model, md in models_raw.items():
            if md.get("count", 0) == 0: continue
            sname = short_model(model)
            pricing = _MODEL_PRICING.get(model)
            mc = 0.0
            if pricing:
                inp_p, out_p, cr_p, cw_p = pricing
                mc = (md.get("input",0)/1e6*inp_p + md.get("output",0)/1e6*out_p +
                      md.get("cache_read",0)/1e6*cr_p + md.get("cache_write",0)/1e6*cw_p)
                total_cost += mc
            total_in = md.get("input",0) + md.get("cache_read",0) + md.get("cache_write",0)
            models.append({"name": sname, "count": md["count"],
                           "input": fmt_tokens(total_in), "output": fmt_tokens(md.get("output",0)),
                           "cost": f"{mc:.0f}" if mc >= 1 else f"{mc:.2f}"})
        models.sort(key=lambda x: x["count"], reverse=True)

        turns = tok.get("turn_count", 0)
        avg_turn = fmt_ms(tok["turn_duration_ms"] // turns) if turns > 0 else ""
        cache_r, cache_w = tok.get("cache_read_tokens", 0), tok.get("cache_write_tokens", 0)
        cache_ratio = f"{cache_r/cache_w:.1f}:1" if cache_w > 0 else ""

        # top tools (exclude WebSearch/WebFetch from main list)
        tools_all = sorted(tok.get("tools", {}).items(), key=lambda x: x[1], reverse=True)
        top_tools = [{"name": n, "count": c} for n, c in tools_all if n not in ("WebSearch","WebFetch")][:6]

        think_pct = round(tok["thinking_blocks"] / tok["message_count"] * 100) if tok.get("message_count") else 0

        today = {
            "sessions": tok.get("session_count", 0),
            "messages": tok.get("message_count", 0),
            "tools": tok.get("tool_call_count", 0),
            "thinking_blocks": tok.get("thinking_blocks", 0),
            "thinking_pct": think_pct,
            "input": fmt_tokens(tok.get("input_tokens", 0)),
            "output": fmt_tokens(tok.get("output_tokens", 0)),
            "cache_read": fmt_tokens(cache_r),
            "cache_write": fmt_tokens(cache_w),
            "cache_ratio": cache_ratio,
            "avg_turn": avg_turn,
            "cost": f"{total_cost:.2f}",
            "models": models,
            "top_tools": top_tools,
        }

    print(json.dumps({
        "session": sess,
        "week": week,
        "week_budget": week_budget,
        "week_sonnet": week_s,
        "wson_budget": wson_budget,
        "extra": extra,
        "today": today,
        "fetching": fetching,
        "age": age,
    }))

except Exception as e:
    import sys
    print(json.dumps({"error": str(e)}), file=sys.stderr)
    import traceback; traceback.print_exc(file=sys.stderr)
    sys.exit(1)
