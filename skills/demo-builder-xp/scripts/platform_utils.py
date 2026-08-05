"""platform_utils.py — cross-platform helpers for demo-builder-xp (macOS + Windows + Linux).

Everything platform-specific lives here so the rest of the pipeline stays OS-agnostic.
"""
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

IS_MAC = sys.platform == "darwin"
IS_WIN = sys.platform.startswith("win")
IS_LINUX = sys.platform.startswith("linux")

OS_NAME = "macOS" if IS_MAC else "Windows" if IS_WIN else "Linux"


def which(name):
    """Resolve an executable, tolerating the .cmd/.exe suffixes npm uses on Windows."""
    cand = [name]
    if IS_WIN:
        cand += [name + ".exe", name + ".cmd", name + ".bat"]
    for c in cand:
        p = shutil.which(c)
        if p:
            return p
    return None


def require(*names):
    """Return the first resolvable exe among names, or None."""
    for n in names:
        p = which(n)
        if p:
            return p
    return None


def chrome_user_data_dir():
    """Path to the real Chrome 'User Data' dir (holds cookies for SSO), per OS."""
    home = Path.home()
    if IS_MAC:
        return home / "Library/Application Support/Google/Chrome"
    if IS_WIN:
        local = os.environ.get("LOCALAPPDATA", str(home / "AppData/Local"))
        return Path(local) / "Google/Chrome/User Data"
    # Linux
    for c in (home / ".config/google-chrome", home / ".config/chromium"):
        if c.exists():
            return c
    return home / ".config/google-chrome"


def ffmpeg_screen_input(fps=30, display=None, region=None):
    """Return (input_args, note) for a full-desktop grab on the current OS.

    region = (w, h, x, y) to crop a window/region (applied where the grabber supports it).
    """
    if IS_MAC:
        # avfoundation: auto-detect the "Capture screen N" device index unless given.
        idx = display if display is not None else _mac_screen_index()
        args = ["-f", "avfoundation", "-capture_cursor", "1", "-framerate", str(fps), "-i", str(idx)]
        return args, f"avfoundation device {idx}"
    if IS_WIN:
        # gdigrab: capture the whole desktop (or a region via offset/size).
        args = ["-f", "gdigrab", "-framerate", str(fps)]
        if region:
            w, h, x, y = region
            args += ["-offset_x", str(x), "-offset_y", str(y), "-video_size", f"{w}x{h}"]
        args += ["-i", "desktop"]
        return args, "gdigrab desktop"
    # Linux: x11grab
    disp = os.environ.get("DISPLAY", ":0.0")
    args = ["-f", "x11grab", "-framerate", str(fps), "-i", disp]
    return args, f"x11grab {disp}"


def _mac_screen_index():
    """Parse ffmpeg avfoundation device list for the first 'Capture screen N' index."""
    ff = require("ffmpeg") or "ffmpeg"
    try:
        out = subprocess.run(
            [ff, "-f", "avfoundation", "-list_devices", "true", "-i", ""],
            capture_output=True, text=True, timeout=20,
        ).stderr
    except Exception:
        return 1
    for line in out.splitlines():
        if "Capture screen" in line:
            # line looks like: [AVFoundation ...] [4] Capture screen 0
            try:
                return int(line.split("]")[1].split("[")[1])
            except Exception:
                continue
    return 1


def screen_recording_hint():
    if IS_MAC:
        return ("macOS needs Screen Recording permission for your terminal: "
                "System Settings > Privacy & Security > Screen Recording.")
    if IS_WIN:
        return ("On Windows, gdigrab captures the visible desktop. Bring the target "
                "window to the foreground before recording.")
    return "On Linux, x11grab uses $DISPLAY; Wayland sessions may need XWayland."


if __name__ == "__main__":
    print(f"OS            : {OS_NAME} ({platform.platform()})")
    print(f"python        : {sys.version.split()[0]}")
    for t in ("ffmpeg", "ffprobe", "node", "npm"):
        print(f"{t:14}: {which(t) or 'MISSING'}")
    print(f"chrome data   : {chrome_user_data_dir()}  (exists={chrome_user_data_dir().exists()})")
    args, note = ffmpeg_screen_input()
    print(f"screen input  : {note}  -> {' '.join(args)}")
    print(f"screen hint   : {screen_recording_hint()}")
