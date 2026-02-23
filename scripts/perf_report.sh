#!/usr/bin/env bash
set -euo pipefail

WINDOW="${1:-10m}"
TMP_LOG="$(mktemp -t iavro-perf.XXXXXX)"
trap 'rm -f "$TMP_LOG"' EXIT

/usr/bin/log show --last "$WINDOW" --style compact --predicate 'eventMessage CONTAINS "[AvroPerf]"' > "$TMP_LOG" 2>/dev/null || true

if ! /usr/bin/grep -q '\[AvroPerf\]' "$TMP_LOG"; then
  echo "No [AvroPerf] logs found in the last ${WINDOW}."
  echo "Tip: enable logs with: defaults write com.omicronlab.inputmethod.AvroSilicon EnablePerfLog -bool true"
  exit 0
fi

python3 - "$TMP_LOG" "$WINDOW" <<'PY'
import re
import sys

log_path, window = sys.argv[1], sys.argv[2]

input_re = re.compile(r"inputText total=([0-9.]+)ms find=([0-9.]+)ms composition=([0-9.]+)ms panel=([0-9.]+)ms")
db_full_re = re.compile(r"database\.find total=([0-9.]+)ms regex=([0-9.]+)ms scan=([0-9.]+)ms cache=(hit|miss) literal=(yes|no) term=.* tables=([0-9]+) scanned=([0-9]+) matched=([0-9]+)")
db_old_re = re.compile(r"database\.find total=([0-9.]+)ms regex=([0-9.]+)ms scan=([0-9.]+)ms term=.* tables=([0-9]+) scanned=([0-9]+) matched=([0-9]+)")
db_hit_re = re.compile(r"database\.find total=([0-9.]+)ms cache=hit term=.* result=([0-9]+)")
panel_re = re.compile(r"updateCandidatesPanel total=([0-9.]+)ms candidates=([0-9]+) visible=([0-9]+)")

stats = {
    "input": {"n": 0, "total": 0.0, "find": 0.0, "comp": 0.0, "panel": 0.0, "max": 0.0, "ge20": 0, "ge30": 0},
    "db": {"n": 0, "total": 0.0, "regex": 0.0, "scan": 0.0, "tables": 0.0, "scanned": 0.0, "matched": 0.0, "max": 0.0, "hit": 0, "literal": 0, "ge20": 0},
    "panel": {"n": 0, "total": 0.0, "cand": 0.0, "max": 0.0, "ge20": 0},
}

def avg(total, count):
    return (total / count) if count else 0.0

def pct(part, total):
    return (100.0 * part / total) if total else 0.0

with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        m = input_re.search(line)
        if m:
            total = float(m.group(1))
            stats["input"]["n"] += 1
            stats["input"]["total"] += total
            stats["input"]["find"] += float(m.group(2))
            stats["input"]["comp"] += float(m.group(3))
            stats["input"]["panel"] += float(m.group(4))
            stats["input"]["max"] = max(stats["input"]["max"], total)
            if total >= 20:
                stats["input"]["ge20"] += 1
            if total >= 30:
                stats["input"]["ge30"] += 1

        m = db_full_re.search(line)
        if m:
            total = float(m.group(1))
            stats["db"]["n"] += 1
            stats["db"]["total"] += total
            stats["db"]["regex"] += float(m.group(2))
            stats["db"]["scan"] += float(m.group(3))
            if m.group(4) == "hit":
                stats["db"]["hit"] += 1
            if m.group(5) == "yes":
                stats["db"]["literal"] += 1
            stats["db"]["tables"] += float(m.group(6))
            stats["db"]["scanned"] += float(m.group(7))
            stats["db"]["matched"] += float(m.group(8))
            stats["db"]["max"] = max(stats["db"]["max"], total)
            if total >= 20:
                stats["db"]["ge20"] += 1
            continue

        m = db_old_re.search(line)
        if m:
            total = float(m.group(1))
            stats["db"]["n"] += 1
            stats["db"]["total"] += total
            stats["db"]["regex"] += float(m.group(2))
            stats["db"]["scan"] += float(m.group(3))
            stats["db"]["tables"] += float(m.group(4))
            stats["db"]["scanned"] += float(m.group(5))
            stats["db"]["matched"] += float(m.group(6))
            stats["db"]["max"] = max(stats["db"]["max"], total)
            if total >= 20:
                stats["db"]["ge20"] += 1
            continue

        m = db_hit_re.search(line)
        if m:
            total = float(m.group(1))
            stats["db"]["n"] += 1
            stats["db"]["hit"] += 1
            stats["db"]["total"] += total
            stats["db"]["max"] = max(stats["db"]["max"], total)
            if total >= 20:
                stats["db"]["ge20"] += 1

        m = panel_re.search(line)
        if m:
            total = float(m.group(1))
            stats["panel"]["n"] += 1
            stats["panel"]["total"] += total
            stats["panel"]["cand"] += float(m.group(2))
            stats["panel"]["max"] = max(stats["panel"]["max"], total)
            if total >= 20:
                stats["panel"]["ge20"] += 1

print(f"AvroPerf Summary (window={window})")
print()

inp = stats["input"]
if inp["n"]:
    print(
        "inputText: "
        f"n={inp['n']} avg_total={avg(inp['total'], inp['n']):.2f}ms "
        f"max_total={inp['max']:.2f}ms "
        f"avg_find={avg(inp['find'], inp['n']):.2f}ms "
        f"avg_comp={avg(inp['comp'], inp['n']):.2f}ms "
        f"avg_panel={avg(inp['panel'], inp['n']):.2f}ms "
        f">=20ms={inp['ge20']} ({pct(inp['ge20'], inp['n']):.1f}%) "
        f">=30ms={inp['ge30']} ({pct(inp['ge30'], inp['n']):.1f}%)"
    )
else:
    print("inputText: no samples")

db = stats["db"]
if db["n"]:
    print(
        "database.find: "
        f"n={db['n']} avg_total={avg(db['total'], db['n']):.2f}ms "
        f"max_total={db['max']:.2f}ms "
        f"avg_regex={avg(db['regex'], db['n']):.2f}ms "
        f"avg_scan={avg(db['scan'], db['n']):.2f}ms "
        f"avg_tables={avg(db['tables'], db['n']):.1f} "
        f"avg_scanned={avg(db['scanned'], db['n']):.0f} "
        f"avg_matched={avg(db['matched'], db['n']):.1f} "
        f"cache_hit={db['hit']} ({pct(db['hit'], db['n']):.1f}%) "
        f"literal={db['literal']} ({pct(db['literal'], db['n']):.1f}%) "
        f">=20ms={db['ge20']} ({pct(db['ge20'], db['n']):.1f}%)"
    )
else:
    print("database.find: no samples")

pan = stats["panel"]
if pan["n"]:
    print(
        "updateCandidatesPanel: "
        f"n={pan['n']} avg_total={avg(pan['total'], pan['n']):.2f}ms "
        f"max_total={pan['max']:.2f}ms "
        f"avg_candidates={avg(pan['cand'], pan['n']):.2f} "
        f">=20ms={pan['ge20']} ({pct(pan['ge20'], pan['n']):.1f}%)"
    )
else:
    print("updateCandidatesPanel: no samples")
PY
