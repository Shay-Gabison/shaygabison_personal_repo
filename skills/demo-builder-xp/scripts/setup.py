#!/usr/bin/env python3
"""setup.py — CROSS-PLATFORM installer for demo-builder-xp. Idempotent, LOCKED-DOWN FRIENDLY.

Built for machines (e.g. managed Microsoft Windows) where large external downloads are blocked.
Nothing large is downloaded by default and every step streams its progress (never looks frozen).

What the DEFAULT install does — all small or already-bundled:
  * verify ffmpeg / node          (prints a per-OS hint if missing; these are system tools)
  * playwright-core (tiny, pure JS) into <work>/node_modules  -> NO browser download; uses the
    Chrome/Edge already on the machine. If npm is blocked, a bundled copy in ../vendor is used.
  * TTS voice, in priority order:
      1. bundled Piper voice (../voices/*.onnx shipped in the zip) + piper-tts if installable
      2. Windows SAPI (built into Windows, ZERO download) — automatic fallback
    No PyTorch, no HuggingFace fetch required.

Opt-in (only if your network allows big downloads):
  --with-kokoro   neural Kokoro voice — pulls in PyTorch (~2 GB). Slow; often blocked on corp nets.
  --no-tts        skip TTS setup entirely.

usage: python setup.py [work_dir] [--with-kokoro | --no-tts]
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import platform_utils as pu


def run(cmd, **kw):
    """Run a command with LIVE output so long installs never look frozen."""
    print("   $ " + " ".join(str(c) for c in cmd))
    return subprocess.run(cmd, **kw)


def hint(tool):
    return (f"brew install {tool}" if pu.IS_MAC else
            f"winget install {tool}" if pu.IS_WIN else
            f"sudo apt-get install -y {tool}")


def main():
    args = sys.argv[1:]
    with_kokoro = "--with-kokoro" in args
    no_tts = "--no-tts" in args
    positional = [a for a in args if not a.startswith("--")]
    work = Path(positional[0]) if positional else Path.home() / "demo_build"
    work.mkdir(parents=True, exist_ok=True)
    venv = work / ".ttsenv"
    vpy = venv / ("Scripts/python.exe" if pu.IS_WIN else "bin/python")

    print(f"== demo-builder-xp setup on {pu.OS_NAME} (locked-down friendly) ==")
    print(f"work dir: {work}\n")

    # ---- 1. ffmpeg / node checks (system tools; not downloaded here) ----------------------
    print("== 1/3  ffmpeg + node (checks only) ==")
    for t in ("ffmpeg", "ffprobe"):
        p = pu.which(t)
        print(f"   {'ok' if p else 'MISSING -> ' + hint('ffmpeg')}: {t}")
    node, npm = pu.which("node"), pu.which("npm")
    print(f"   {'ok: node' if node else 'MISSING -> ' + hint('node') + ' (or nodejs.org)'}")

    # ---- 2. playwright-core (tiny; never downloads a browser) -----------------------------
    print("\n== 2/3  playwright-core (uses installed Chrome/Edge — no browser download) ==")
    setup_playwright(work, npm)
    setup_pw_ffmpeg(work, node)
    setup_qa_deps()
    setup_edge_tts()

    # ---- 3. TTS: bundled Piper -> SAPI fallback (no large download) -----------------------
    if no_tts:
        print("\n== 3/3  TTS: skipped (--no-tts) ==")
    else:
        print("\n== 3/3  TTS (light: bundled Piper, else Windows SAPI) ==")
        setup_tts(work, venv, vpy)
        if with_kokoro:
            install_kokoro(vpy, venv)

    finish(work)


def setup_playwright(work, npm):
    nm = work / "node_modules"
    if (nm / "playwright-core").exists() or (nm / "playwright").exists():
        print("   ok: playwright already present in", nm)
        return
    vendor = ROOT / "vendor" / "node_modules" / "playwright-core"
    if vendor.exists():
        nm.mkdir(parents=True, exist_ok=True)
        dst = nm / "playwright-core"
        if not dst.exists():
            print(f"   using bundled playwright-core -> {dst}")
            shutil.copytree(vendor, dst)
        return
    if npm:
        if not (work / "package.json").exists():
            run([npm, "init", "-y"], cwd=work, stdout=subprocess.DEVNULL)
        env = os.environ.copy()
        env["PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD"] = "1"
        run([npm, "i", "playwright-core"], cwd=work, env=env)
        print("   note: demos use channel:'chrome' (falls back to 'msedge').")
    else:
        print("   MISSING: npm and no bundled copy — install Node, or unzip the vendor/ folder.")


def setup_pw_ffmpeg(work, node):
    """Install Playwright's tiny ffmpeg helper (~1.5 MB) needed for recordVideo (panel.webm).
    This is NOT a browser download — recordVideo uses this bundled ffmpeg, not the system one."""
    nm = work / "node_modules"
    cli = nm / "playwright-core" / "cli.js"
    if not cli.exists() or not node:
        print("   skip: playwright ffmpeg helper (need node + playwright-core)")
        return
    # already installed? default cache is %LOCALAPPDATA%\ms-playwright (win) / ~/Library/Caches/ms-playwright (mac) / ~/.cache/ms-playwright (linux)
    if pu.IS_WIN:
        cache = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "ms-playwright"
    elif pu.IS_MAC:
        cache = Path.home() / "Library" / "Caches" / "ms-playwright"
    else:
        cache = Path.home() / ".cache" / "ms-playwright"
    if cache.exists() and any(cache.glob("ffmpeg-*")):
        print("   ok: playwright ffmpeg helper already present")
        return
    print("   installing playwright ffmpeg helper (tiny; needed for panel recording) ...")
    run([node, str(cli), "install", "ffmpeg"], cwd=work)


def setup_qa_deps():
    """Install the small QA deps (numpy + Pillow) into the running interpreter so
    check_demo.py can score the demo. Both are small wheels; skip-safe if blocked."""
    have = True
    for mod in ("numpy", "PIL"):
        if run([sys.executable, "-c", f"import {mod}"], capture_output=True).returncode != 0:
            have = False
    if have:
        print("   ok: QA deps (numpy, Pillow) already present")
        return
    print("   installing QA deps (numpy, Pillow; small, skip-safe) ...")
    run([sys.executable, "-m", "pip", "install", "numpy", "Pillow"])


def setup_edge_tts():
    """Install edge-tts (Azure neural voices) into the running interpreter — TINY pure-python
    package (no PyTorch). Gives natural voices (Andrew/Aria/Guy/Emma...) far better than SAPI.
    Skip-safe: if pip is blocked, tts.py falls back to SAPI automatically."""
    if run([sys.executable, "-c", "import edge_tts"], capture_output=True).returncode == 0:
        print("   ok: edge-tts (neural voices) already present")
        return
    print("   installing edge-tts (neural voices; tiny, no PyTorch, skip-safe) ...")
    run([sys.executable, "-m", "pip", "install", "edge-tts"])


def setup_tts(work, venv, vpy):
    voices_src = ROOT / "voices"
    voices_dst = work / "voices"
    voices_dst.mkdir(parents=True, exist_ok=True)
    bundled = list(voices_src.glob("*.onnx")) if voices_src.exists() else []
    for v in bundled:
        for suffix in ("", ".json"):
            s = Path(str(v) + suffix)
            d = voices_dst / s.name
            if s.exists() and not d.exists():
                shutil.copy2(s, d)
    if bundled:
        print(f"   ok: bundled Piper voice(s): {', '.join(v.stem for v in bundled)}")
        # try to install the tiny piper runtime (no torch); OK if it fails -> SAPI fallback
        if not venv.exists():
            run([sys.executable, "-m", "venv", str(venv)])
        if Path(vpy).exists():
            if run([str(vpy), "-c", "import piper"], capture_output=True).returncode != 0:
                print("   installing piper-tts (small; skip-safe) ...")
                run([str(vpy), "-m", "pip", "install", "piper-tts"])
            ok = run([str(vpy), "-c", "import piper"], capture_output=True).returncode == 0
            print("   ok: piper runtime" if ok else
                  "   piper runtime unavailable — will use Windows SAPI fallback")
    else:
        print("   no bundled voice found.")
    if pu.IS_WIN:
        print("   Windows SAPI is available as a zero-install fallback (tts.py --engine sapi).")


def install_kokoro(vpy, venv):
    print("\n== Kokoro neural voice (OPT-IN) ==")
    print("   WARNING: installs PyTorch (~2 GB). Often blocked on managed networks; may be slow.")
    if not venv.exists():
        run([sys.executable, "-m", "venv", str(venv)])
    if not Path(vpy).exists():
        print("   venv missing; aborting kokoro install")
        return
    run([str(vpy), "-m", "pip", "install", "torch",
         "--index-url", "https://download.pytorch.org/whl/cpu"])
    run([str(vpy), "-m", "pip", "install", "kokoro", "soundfile"])
    ok = run([str(vpy), "-c", "from kokoro import KPipeline"], capture_output=True).returncode == 0
    print("   ok: kokoro" if ok else "   kokoro install failed (network likely blocked it)")


def finish(work):
    py = "python" if pu.IS_WIN else "python3"
    print(f"\nReady. Verify with:  {py} demo.py doctor")
    print("Default voice = bundled Piper (offline). No large downloads were required.")
    print("Neural voice is optional:  setup.py --with-kokoro   (needs ~2 GB PyTorch).")


if __name__ == "__main__":
    main()
