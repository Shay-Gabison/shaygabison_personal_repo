#!/usr/bin/env python3
"""demo.py — CROSS-PLATFORM demo-builder orchestrator (macOS / Windows / Linux).

One entry point for the whole pipeline. Every step shells out to a cross-platform helper
(Python or Node/Playwright) — no bash, tmux, asciinema, agg or Homebrew required.

Subcommands
  doctor                              environment check (OS, ffmpeg, node, chrome, tts venv)
  cards   <deck.html> <outdir> <id:dur,...>       deck slides -> card_<id>.webm  (render_cards.js)
  panel   <spec.json> <out.webm>                  terminal/code/logs panel        (capture_panel.js)
  browser <url> <out.webm> <secs> [scrollPx] [zoom]  authed portal/ADO capture    (capture_browser.js)
  screen  <out.mp4> <secs> [--region WxH+X+Y] [--display N]   native window/desktop (capture_screen.py)
  tts     <txt> <out.wav> [voice] [engine]        narration                        (tts.py)
  stitch  <out.mp4> vid=wav vid=wav ...           mux + concat -> final MP4        (stitch.py)
  qa      <mp4> --sections "n:s:e,..." --expect "kw,..." [--out r.json]  self-QA   (check_demo.py)

Node scripts use NODE_PATH so Playwright resolves from ~/demo_build/node_modules.
"""
import os
import subprocess
import sys
from pathlib import Path

import platform_utils as pu

HERE = Path(__file__).resolve().parent
WORK = Path(os.environ.get("WORK", str(Path.home() / "demo_build")))


def node_env():
    env = os.environ.copy()
    nm = WORK / "node_modules"
    existing = env.get("NODE_PATH", "")
    env["NODE_PATH"] = f"{nm}{os.pathsep}{existing}" if existing else str(nm)
    return env


def run_node(script, args):
    node = pu.require("node")
    if not node:
        sys.exit("node not found — run: python demo.py doctor")
    return subprocess.run([node, str(HERE / script), *args], env=node_env()).returncode


def run_py(script, args):
    return subprocess.run([sys.executable, str(HERE / script), *args]).returncode


def doctor():
    print(f"OS            : {pu.OS_NAME}")
    print(f"python        : {sys.version.split()[0]}  ({sys.executable})")
    for t in ("ffmpeg", "ffprobe", "node", "npm"):
        print(f"{t:14}: {pu.which(t) or 'MISSING — see setup.py'}")
    cd = pu.chrome_user_data_dir()
    print(f"chrome profile: {cd}  (exists={cd.exists()})")
    nm = WORK / "node_modules" / "playwright"
    print(f"playwright    : {'installed' if nm.exists() else 'MISSING (npm i playwright)'} @ {WORK/'node_modules'}")
    tts = None
    for rel in ("Scripts/python.exe", "bin/python", "bin/python3"):
        p = WORK / ".ttsenv" / rel
        if p.exists():
            tts = p
            break
    print(f"tts venv      : {tts or 'MISSING (run setup.py)'}")
    print(f"work dir      : {WORK}  (exists={WORK.exists()})")
    print(f"screen hint   : {pu.screen_recording_hint()}")
    return 0


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd, rest = sys.argv[1], sys.argv[2:]
    if cmd == "doctor":
        sys.exit(doctor())
    elif cmd == "cards":
        sys.exit(run_node("render_cards.js", rest))
    elif cmd == "panel":
        sys.exit(run_node("capture_panel.js", rest))
    elif cmd == "browser":
        sys.exit(run_node("capture_browser.js", rest))
    elif cmd == "screen":
        sys.exit(run_py("capture_screen.py", rest))
    elif cmd == "tts":
        sys.exit(run_py("tts.py", rest))
    elif cmd == "stitch":
        sys.exit(run_py("stitch.py", rest))
    elif cmd == "qa":
        sys.exit(run_py("check_demo.py", rest))
    else:
        sys.exit(f"unknown subcommand '{cmd}'\n{__doc__}")


if __name__ == "__main__":
    main()
