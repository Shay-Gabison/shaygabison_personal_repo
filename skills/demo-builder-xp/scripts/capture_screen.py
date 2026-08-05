#!/usr/bin/env python3
"""capture_screen.py — CROSS-PLATFORM native screen / window / region capture.

Records any native GUI app that is not a browser or terminal (desktop metrics viewers, native
portals, an IDE app, Excel/Power BI, a video). Uses the OS-appropriate ffmpeg grabber:
  macOS   -> avfoundation   Windows -> gdigrab   Linux -> x11grab
and normalizes the result to a 1440x900 mp4.

usage: python capture_screen.py <out.mp4> <seconds> [--region WxH+X+Y] [--display N] [--fps 30]
"""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

import platform_utils as pu

BG = "0x0b0e14"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("seconds", type=float)
    ap.add_argument("--region", help="WxH+X+Y crop in screen pixels")
    ap.add_argument("--display", type=int, default=None)
    ap.add_argument("--fps", type=int, default=30)
    a = ap.parse_args()

    ff = pu.require("ffmpeg")
    if not ff:
        sys.exit("ffmpeg not found")

    region = None
    if a.region:
        try:
            wh, xy = a.region.split("+", 1)
            w, h = wh.lower().split("x")
            x, y = xy.split("+")
            region = (int(w), int(h), int(x), int(y))
        except Exception:
            sys.exit(f"bad --region '{a.region}', expected WxH+X+Y")

    in_args, note = pu.ffmpeg_screen_input(fps=a.fps, display=a.display, region=region)
    raw = str(Path(tempfile.gettempdir()) / "dbxp_screen_raw.mkv")

    print(f"[capture_screen] {pu.OS_NAME}: {note}")
    print(f"[capture_screen] {pu.screen_recording_hint()}")

    grab = [ff, "-loglevel", "error", "-y", *in_args, "-t", str(a.seconds),
            "-c:v", "libx264", "-preset", "ultrafast", "-crf", "18", raw]
    r = subprocess.run(grab)
    if r.returncode != 0 or not Path(raw).exists():
        sys.exit("screen capture failed — check screen-recording permission / target window visibility")

    # crop (mac/linux need it in the filter; gdigrab already cropped via input args)
    pre = ""
    if region and not pu.IS_WIN:
        w, h, x, y = region
        pre = f"crop={w}:{h}:{x}:{y},"
    vf = (f"{pre}scale=1440:900:force_original_aspect_ratio=decrease,"
          f"pad=1440:900:(ow-iw)/2:(oh-ih)/2:color={BG},fps=30,format=yuv420p,setsar=1")
    enc = [ff, "-loglevel", "error", "-y", "-i", raw, "-vf", vf,
           "-c:v", "libx264", "-crf", "20", "-preset", "medium", a.out]
    subprocess.run(enc, check=True)
    Path(raw).unlink(missing_ok=True)
    print(f"screen clip -> {a.out} ({a.seconds}s)")


if __name__ == "__main__":
    main()
