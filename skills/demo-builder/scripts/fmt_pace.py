#!/usr/bin/env python3
# Reads kubectl JSON log lines on stdin, prints a readable colored line, paces output (live-tail feel).
# Generic: set FMT_DROP_PREFIX to a logger prefix to strip from every line (e.g. "myapp.") so the
# name column isn't dominated by a redundant app prefix. FMT_MAXMSG caps message width (no wrap).
import sys, json, time, random, os
C={'INFO':'\033[32m','WARNING':'\033[33m','ERROR':'\033[31m','DEBUG':'\033[90m'}
R='\033[0m'; CY='\033[36m'; DI='\033[90m'; WH='\033[97m'
DROP=os.environ.get('FMT_DROP_PREFIX','')          # e.g. "contosovalidation." -> stripped from name
MAXMSG=int(os.environ.get('FMT_MAXMSG','82'))      # cap message length so lines don't wrap
for raw in sys.stdin:
    raw=raw.strip()
    if not raw: continue
    ts=lvl=name=msg=None
    try:
        o=json.loads(raw[raw.index('{'):]) if '{' in raw else {}
        ts=o.get('asctime') or o.get('time') or ''
        lvl=(o.get('levelname') or o.get('level') or 'INFO').upper()
        name=o.get('name') or o.get('logger') or ''
        msg=o.get('message') or o.get('line') or ''
    except Exception:
        msg=raw; lvl='INFO'; ts=''; name=''
    t=ts.split(' ')[-1] if ts else ''
    col=C.get(lvl,'\033[32m')
    short={'WARNING':'WARN','ERROR':'ERR','CRITICAL':'CRIT'}.get(lvl,lvl)
    # drop a redundant app prefix (configurable) that prefixes every logger name
    nm=name[len(DROP):] if DROP and name.startswith(DROP) else name
    if len(nm)>20: nm=nm[:19]+'\u2026'
    # bound very long messages so lines don't wrap the terminal
    if len(msg)>MAXMSG: msg=msg[:MAXMSG-1]+'\u2026'
    line=f"{DI}{t}{R} {col}{short:<5}{R} {CY}{nm:<20}{R} {WH}{msg}{R}"
    sys.stdout.write(line+"\n"); sys.stdout.flush()
    time.sleep(random.uniform(0.12,0.40))
