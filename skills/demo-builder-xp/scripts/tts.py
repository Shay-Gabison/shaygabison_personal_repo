#!/usr/bin/env python3
"""tts.py — CROSS-PLATFORM narration synthesis, LOCKED-DOWN FRIENDLY.

Engine priority (auto): the demo works even on a managed machine that blocks large packages.
  1. edge    — Azure neural voices (Andrew/Aria/Guy/Emma...), TINY pip (edge-tts, no PyTorch)
  2. kokoro  — neural, best quality, but needs PyTorch (opt-in via setup.py --with-kokoro)
  3. piper   — light offline voice (bundled .onnx, no PyTorch)
  4. sapi    — Windows built-in System.Speech (ZERO install, offline)   [Windows only]
  5. say     — macOS built-in (fallback so a Mac never hard-fails)      [macOS only]

By default engine="auto" picks the first one that is actually available on this machine, so you
never get a hard failure just because a package could not be downloaded.

usage: python tts.py <txtfile> <out.wav> [voice] [engine=auto] [--work DIR]
  engine: auto | edge | kokoro | piper | sapi | say
  edge voices: any Azure short name, e.g. en-US-AndrewNeural, en-US-AriaNeural, en-US-GuyNeural,
               en-US-EmmaNeural, en-US-BrianNeural, en-US-JennyNeural (also friendly: andrew/aria/...).
  Kokoro voices: am_michael, am_adam, af_heart, bm_george (bm_* => British).
  Piper default voice: en_US-lessac-medium (bundled).
Spell tricky terms phonetically in the text (E V two, k nine s, M D A).
"""
import argparse
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PIPER_DEFAULT = "en_US-lessac-medium"
EDGE_DEFAULT = "en-US-AndrewNeural"

# Friendly aliases -> Azure edge-tts short names.
EDGE_ALIASES = {
    "andrew": "en-US-AndrewNeural", "aria": "en-US-AriaNeural",
    "guy": "en-US-GuyNeural", "emma": "en-US-EmmaNeural",
    "brian": "en-US-BrianNeural", "jenny": "en-US-JennyNeural",
    "christopher": "en-US-ChristopherNeural", "michelle": "en-US-MichelleNeural",
    # let kokoro-style names fall back to a sensible neural voice too
    "am_michael": "en-US-AndrewNeural", "am_adam": "en-US-GuyNeural",
    "af_heart": "en-US-AriaNeural", "bm_george": "en-GB-RyanNeural",
    "default": EDGE_DEFAULT,
}


def edge_voice(voice: str) -> str:
    if not voice:
        return EDGE_DEFAULT
    if "Neural" in voice:              # already a full short name
        return voice
    return EDGE_ALIASES.get(voice.lower(), EDGE_DEFAULT)


def venv_python(work: Path):
    for rel in ("Scripts/python.exe", "bin/python", "bin/python3"):
        p = work / ".ttsenv" / rel
        if p.exists():
            return str(p)
    return sys.executable


def has_kokoro(vpy):
    return subprocess.run([vpy, "-c", "import kokoro"], capture_output=True).returncode == 0


def has_edge(vpy):
    return subprocess.run([vpy, "-c", "import edge_tts"], capture_output=True).returncode == 0


def synth_edge(vpy, voice, txt, out):
    """Azure neural voices via edge-tts (tiny pip, no PyTorch). Writes mp3, then ffmpeg -> wav.
    Needs outbound network to speech.platform.bing.com; caller falls back if it fails."""
    v = edge_voice(voice)
    mp3 = str(Path(out).with_suffix(".edge.mp3"))
    rc = subprocess.run([vpy, "-m", "edge_tts", "--voice", v, "--file", txt,
                         "--write-media", mp3], capture_output=True).returncode
    if rc != 0 or not Path(mp3).exists() or Path(mp3).stat().st_size < 512:
        return 1
    ff = subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", mp3,
                         "-ar", "24000", "-ac", "1", out], capture_output=True).returncode
    try:
        Path(mp3).unlink()
    except OSError:
        pass
    return ff


def has_piper(vpy, work):
    ok = subprocess.run([vpy, "-c", "import piper"], capture_output=True).returncode == 0
    return ok and piper_voice_path(work, PIPER_DEFAULT) is not None


def piper_voice_path(work, voice):
    """Resolve a usable piper .onnx: exact name, else the first bundled voice."""
    exact = work / "voices" / f"{voice}.onnx"
    if exact.exists():
        return exact
    found = sorted((work / "voices").glob("*.onnx")) if (work / "voices").exists() else []
    return found[0] if found else None


def synth_kokoro(vpy, voice, txt, out):
    lang = "b" if voice.startswith(("bm_", "bf_")) else "a"
    return subprocess.run([vpy, str(HERE / "kokoro_synth.py"), voice, txt, out, "1.0", lang]).returncode


def synth_piper(vpy, work, voice, txt, out):
    model = piper_voice_path(work, voice)
    if model is None:
        return 1
    with open(txt) as f:
        # piper-tts CLI: python -m piper -m MODEL -f OUT  (reads text on stdin)
        return subprocess.run([vpy, "-m", "piper", "-m", str(model),
                               "--sentence-silence", "0.32", "-f", out],
                              stdin=f).returncode


def synth_sapi(txt_path, out):
    """Windows System.Speech (SAPI) via PowerShell — no install, offline."""
    text = Path(txt_path).read_text(encoding="utf-8").replace("\n", " ").replace("'", "''")
    ps = (
        "Add-Type -AssemblyName System.Speech; "
        "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
        f"$s.SetOutputToWaveFile('{Path(out).resolve()}'); "
        f"$s.Speak('{text}'); $s.Dispose();"
    )
    exe = "powershell" if sys.platform.startswith("win") else "pwsh"
    return subprocess.run([exe, "-NoProfile", "-Command", ps]).returncode


def synth_say(txt_path, out):
    """macOS 'say' fallback so a Mac never hard-fails (rejected for final Mac demos)."""
    aiff = str(Path(out).with_suffix(".aiff"))
    if subprocess.run(["say", "-o", aiff, "-f", txt_path]).returncode != 0:
        return 1
    return subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", aiff, out]).returncode


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("txt")
    ap.add_argument("out")
    ap.add_argument("voice", nargs="?", default="am_michael")
    ap.add_argument("engine", nargs="?", default="auto")
    ap.add_argument("--work", default=str(Path.home() / "demo_build"))
    a = ap.parse_args()

    work = Path(a.work)
    vpy = venv_python(work)

    if a.engine == "auto":
        order = []
        if has_edge(vpy):
            order.append("edge")
        if has_kokoro(vpy):
            order.append("kokoro")
        if has_piper(vpy, work):
            order.append("piper")
        if sys.platform.startswith("win"):
            order.append("sapi")
        elif sys.platform == "darwin":
            order.append("say")
    else:
        order = [a.engine]

    if not order:
        sys.exit("No TTS engine available. Run: python setup.py (installs the bundled Piper voice), "
                 "or on Windows use --engine sapi (no install needed).")

    for eng in order:
        print(f"[tts] trying engine: {eng}")
        if eng == "edge":
            rc = synth_edge(vpy, a.voice, a.txt, a.out)
        elif eng == "kokoro":
            rc = synth_kokoro(vpy, a.voice, a.txt, a.out)
        elif eng == "piper":
            rc = synth_piper(vpy, work, a.voice, a.txt, a.out)
        elif eng == "sapi":
            rc = synth_sapi(a.txt, a.out)
        elif eng == "say":
            rc = synth_say(a.txt, a.out)
        else:
            rc = 1
        if rc == 0 and Path(a.out).exists():
            print(f"[tts] ok via {eng} -> {a.out}")
            return
        print(f"[tts] engine {eng} failed, trying next ...")

    sys.exit(f"TTS failed for all engines tried: {', '.join(order)}")


if __name__ == "__main__":
    main()
