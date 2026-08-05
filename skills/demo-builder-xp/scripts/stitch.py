#!/usr/bin/env python3
"""stitch.py — CROSS-PLATFORM port of stitch.sh (macOS / Windows / Linux).

Muxes each section (video governs length, narration audio padded), then concatenates to a final
1440x900 30fps MP4. Auto-trims the flat pre-paint head of each section (same grayscale-stddev
metric as check_demo.py) and clone-pads the tail so section length / narration stay in sync.

usage:
  python stitch.py <out.mp4> vid1.webm=narr1.wav vid2.mp4=narr2.wav ...
    (audio optional per pair: "vid.webm=" or just "vid.webm" for a silent section)
env: WORK (default ~/demo_build), TRIM_FLAT_HEAD=0 to disable, FLAT_STD, FLAT_MAXHEAD
"""
import glob
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import platform_utils as pu

BG = "0x0b0e14"
FF = pu.require("ffmpeg") or "ffmpeg"
FP = pu.require("ffprobe") or "ffprobe"

WORK = Path(os.environ.get("WORK", str(Path.home() / "demo_build")))
TRIM = os.environ.get("TRIM_FLAT_HEAD", "1") != "0"
FLAT_STD = float(os.environ.get("FLAT_STD", "7"))
FLAT_MAXHEAD = float(os.environ.get("FLAT_MAXHEAD", "1.5"))
# When a section has a long blank/loading head (e.g. an SPA painting white for ~10s), padding it
# back as a frozen tail just trades a blank glitch for a static tail. FLAT_NOPAD=1 instead trims
# the blank head and lets the section shorten — which also removes the dead-air silence there.
FLAT_NOPAD = os.environ.get("FLAT_NOPAD", "0") != "0"


def duration(path):
    out = subprocess.run([FP, "-loglevel", "quiet", "-show_entries", "format=duration",
                          "-of", "default=nw=1:nk=1", path], capture_output=True, text=True)
    try:
        return float(out.stdout.strip())
    except ValueError:
        return 0.0


def first_nonflat(video):
    """Seconds of the first non-flat frame within FLAT_MAXHEAD (empty => none). Needs PIL."""
    try:
        from PIL import Image, ImageStat
    except Exception:
        return None
    td = tempfile.mkdtemp()
    subprocess.run([FF, "-loglevel", "error", "-t", str(FLAT_MAXHEAD), "-i", video,
                    "-vf", "fps=10,scale=480:-1", "-vsync", "0", os.path.join(td, "%03d.png")],
                   capture_output=True)
    hit = None
    for i, f in enumerate(sorted(glob.glob(os.path.join(td, "*.png")))):
        if ImageStat.Stat(Image.open(f).convert("L")).stddev[0] >= FLAT_STD:
            hit = round(i * 0.1, 3)
            break
    for f in glob.glob(os.path.join(td, "*.png")):
        os.remove(f)
    os.rmdir(td)
    return hit


def mux(video, audio, out):
    head = first_nonflat(video) if TRIM else None
    ss = []
    pad = ""
    if head and head >= 0.12:
        ss = ["-ss", str(head)]
        if not FLAT_NOPAD:
            pad = f",tpad=stop_mode=clone:stop_duration={head}"
    vf = (f"scale=1440:900:force_original_aspect_ratio=decrease,"
          f"pad=1440:900:(ow-iw)/2:(oh-ih)/2:color={BG},fps=30{pad},format=yuv420p,setsar=1")
    if audio:
        cmd = [FF, "-loglevel", "error", "-y", *ss, "-i", video, "-i", audio,
               "-filter_complex",
               f"[0:v]{vf}[v];[1:a]aresample=48000,apad,pan=stereo|c0=c0|c1=c0[a]",
               "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-crf", "20", "-preset", "medium",
               "-c:a", "aac", "-b:a", "160k", "-ar", "48000", "-shortest", out]
    else:
        cmd = [FF, "-loglevel", "error", "-y", *ss, "-i", video,
               "-f", "lavfi", "-i", "anullsrc=cl=stereo:r=48000", "-vf", vf,
               "-c:v", "libx264", "-crf", "20", "-c:a", "aac", "-b:a", "160k", "-ar", "48000",
               "-shortest", out]
    subprocess.run(cmd, check=True)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    out = sys.argv[1]
    pairs = sys.argv[2:]
    sec_dir = WORK / "_sections"
    sec_dir.mkdir(parents=True, exist_ok=True)
    listf = sec_dir / "list.txt"
    entries = []
    for i, pair in enumerate(pairs):
        if "=" in pair:
            v, a = pair.split("=", 1)
        else:
            v, a = pair, ""
        s = str(sec_dir / f"s{i}.mp4")
        mux(v, a or None, s)
        entries.append(f"file '{s}'")
        print(f"  section {i}: {os.path.basename(v)}  ({duration(s):.2f}s)")
    listf.write_text("\n".join(entries) + "\n")
    subprocess.run([FF, "-loglevel", "error", "-y", "-f", "concat", "-safe", "0",
                    "-i", str(listf), "-c", "copy", out], check=True)
    print(f"final -> {out}  ({duration(out):.2f}s)")


if __name__ == "__main__":
    main()
