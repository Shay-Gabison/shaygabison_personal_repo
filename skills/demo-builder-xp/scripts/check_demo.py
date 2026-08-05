#!/usr/bin/env python3
"""check_demo.py — automated QA for a narrated screen-recording demo.

Samples frames, scores each for sharpness / blankness / motion, OCRs text to catch
"screenshot-not-live" static stretches and bad frames (login / loading / error pages),
and checks the audio track for loudness and long silent gaps. Emits a JSON report and a
human-readable scorecard so the agent can iterate WITHOUT the user.

usage:
  check_demo.py <video.mp4> [--sections sectionspec] [--expect "kw1,kw2,..."] [--out report.json]

  sectionspec (optional): comma list of name:start:end (seconds) to score per logical section,
    e.g. "title:0:23,code:23:47,build:47:70,ev2:70:90,livelogs:90:114,dryrun:114:135,end:135:146"
  --expect: comma-separated keywords that SHOULD appear somewhere (case-insensitive OCR match).

Requires: ffmpeg, tesseract on PATH; Pillow + numpy in the venv.
"""
import sys, os, json, subprocess, tempfile, glob, re, math, shutil
import numpy as np
from PIL import Image

# OCR (tesseract) is OPTIONAL — it powers bad-page detection + keyword checks. When it's
# not installed (common on locked-down machines) we skip those checks instead of crashing.
HAS_OCR = shutil.which("tesseract") is not None

BAD_PATTERNS = [
    r"loading identity", r"sign in", r"sign-in", r"enter.*password", r"stale request",
    r"something went wrong", r"page not found", r"\b404 not found\b", r"\b403 forbidden\b", r"access denied",
    r"error 50\d", r"we can.?t sign you in", r"loading\.\.\.",
]

def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)

def ffprobe_dur(path):
    r = run(["ffprobe","-loglevel","quiet","-show_entries","format=duration","-of","default=nw=1:nk=1",path])
    try: return float(r.stdout.strip())
    except: return 0.0

def has_audio(path):
    r = run(["ffprobe","-loglevel","error","-select_streams","a","-show_entries","stream=codec_type","-of","csv",path])
    return "audio" in r.stdout

def extract_frames(path, fps, outdir):
    os.makedirs(outdir, exist_ok=True)
    # scale down to ~1100px wide: keeps OCR legible but is much faster than full 1440.
    run(["ffmpeg","-loglevel","error","-y","-i",path,"-vf",f"fps={fps},scale=1100:-1",os.path.join(outdir,"f_%04d.png")])
    return sorted(glob.glob(os.path.join(outdir,"f_*.png")))

def gray(arr):
    return arr[...,:3].mean(axis=2) if arr.ndim==3 else arr

def sharpness(g):
    # variance of Laplacian (higher = sharper)
    k = np.array([[0,1,0],[1,-4,1],[0,1,0]],dtype=np.float32)
    from numpy.lib.stride_tricks import sliding_window_view
    if g.shape[0]<3 or g.shape[1]<3: return 0.0
    w = sliding_window_view(g.astype(np.float32),(3,3))
    lap = (w*k).sum(axis=(-1,-2))
    return float(lap.var())

def blankness(g):
    # fraction of "flat" content: low global stddev => blank/near-blank
    return float(g.std())

def motion(g_prev, g):
    if g_prev is None: return None
    h=min(g_prev.shape[0],g.shape[0]); w=min(g_prev.shape[1],g.shape[1])
    d=np.abs(g_prev[:h,:w]-g[:h,:w])
    return float(d.mean())

def ocr(path):
    if not HAS_OCR:
        return ""
    try:
        r = run(["tesseract",path,"stdout","--psm","6"])
        return r.stdout.lower()
    except FileNotFoundError:
        return ""

def audio_stats(path):
    with tempfile.TemporaryDirectory() as td:
        wav=os.path.join(td,"a.wav")
        run(["ffmpeg","-loglevel","error","-y","-i",path,"-ac","1","-ar","16000",wav])
        if not os.path.exists(wav): return None
        import wave
        wf=wave.open(wav,'rb'); n=wf.getnframes(); sr=wf.getframerate()
        raw=wf.readframes(n); wf.close()
        a=np.frombuffer(raw,dtype=np.int16).astype(np.float32)/32768.0
        if len(a)==0: return None
        win=int(sr*0.5); rms=[]
        for i in range(0,len(a)-win,win):
            seg=a[i:i+win]; rms.append(float(np.sqrt((seg**2).mean())+1e-9))
        rms=np.array(rms)
        thr=max(0.01, rms.max()*0.06)
        silent=rms<thr
        # longest run of silence (in 0.5s windows)
        longest=cur=0
        gaps=[]; start=None
        for idx,s in enumerate(silent):
            if s:
                cur+=1
                if start is None: start=idx
            else:
                if cur>=3: gaps.append((round(start*0.5,1), round(idx*0.5,1)))
                longest=max(longest,cur); cur=0; start=None
        if cur>=3: gaps.append((round(start*0.5,1), round(len(silent)*0.5,1)))
        longest=max(longest,cur)
        overall_db=20*math.log10(float(np.sqrt((a**2).mean()))+1e-9)
        return {"overall_db":round(overall_db,1),"longest_silence_s":round(longest*0.5,1),
                "silence_gaps":gaps[:12],"n_windows":len(rms)}

def main():
    if len(sys.argv)<2:
        print(__doc__); sys.exit(1)
    path=sys.argv[1]
    sections=None; expect=[]; out="report.json"; fps=1.0
    args=sys.argv[2:]
    for i,a in enumerate(args):
        if a=="--sections" and i+1<len(args): sections=args[i+1]
        if a=="--expect" and i+1<len(args): expect=[x.strip().lower() for x in args[i+1].split(",") if x.strip()]
        if a=="--out" and i+1<len(args): out=args[i+1]
        if a=="--fps" and i+1<len(args): fps=float(args[i+1])

    dur=ffprobe_dur(path); aud=has_audio(path)
    with tempfile.TemporaryDirectory() as td:
        frames=extract_frames(path,fps,td)
        per=[]; g_prev=None; alltext=[]
        for idx,f in enumerate(frames):
            t=round(idx/fps,2)
            im=Image.open(f).convert("RGB"); arr=np.asarray(im)
            g=gray(arr)
            # downsample for speed on motion/sharpness
            gs=np.asarray(Image.fromarray(g.astype(np.uint8)).resize((480,300)))
            shp=sharpness(gs); blk=blankness(gs); mot=motion(g_prev,gs); g_prev=gs
            txt=ocr(f); alltext.append(txt)
            bad=[p for p in BAD_PATTERNS if re.search(p,txt)]
            per.append({"t":t,"sharpness":round(shp,1),"stddev":round(blk,1),
                        "motion":None if mot is None else round(mot,3),
                        "textlen":len(txt.strip()),"bad":bad})
        alltext_join=" ".join(alltext)

    # section scoring
    secs=[]
    if sections:
        for spec in sections.split(","):
            name,s,e=spec.split(":"); s=float(s); e=float(e)
            fr=[p for p in per if s<=p["t"]<e]
            if not fr: continue
            mots=[p["motion"] for p in fr if p["motion"] is not None]
            shps=[p["sharpness"] for p in fr]
            blks=[p["stddev"] for p in fr]
            badf=[p for p in fr if p["bad"]]
            avg_mot=round(float(np.mean(mots)),3) if mots else 0.0
            # static if very low motion across the whole section (looks like a screenshot)
            secs.append({"name":name,"start":s,"end":e,"frames":len(fr),
                         "avg_motion":avg_mot,"max_motion":round(max(mots),3) if mots else 0.0,
                         "avg_sharpness":round(float(np.mean(shps)),1),
                         "min_stddev":round(min(blks),1),
                         "bad_frames":[{"t":b["t"],"bad":b["bad"]} for b in badf]})

    # checks / issues
    issues=[]
    if not aud: issues.append("NO AUDIO TRACK")
    # flat = near-uniform frame (white OR black). stddev<6 catches both. Only a brief
    # (<=1s) fade at the very start/end is acceptable; anything longer is a visible
    # glitch (e.g. browser white pre-paint) and must be flagged.
    flat=[p["t"] for p in per if p["stddev"]<6]
    blank_frames=[t for t in flat if t>1.0 and t<dur-1.0]
    if blank_frames: issues.append(f"flat/blank frames (white or black glitch) at {blank_frames[:8]}")
    bad_any=[(p["t"],p["bad"]) for p in per if p["bad"]]
    if bad_any: issues.append(f"bad page frames (login/loading/error): {bad_any[:8]}")
    low_text=[p["t"] for p in per if p["textlen"]<10]
    # expected keywords (only meaningful when OCR is available)
    missing=[kw for kw in expect if kw not in alltext_join] if HAS_OCR else []
    if missing: issues.append(f"expected keywords NOT found via OCR: {missing}")
    if not HAS_OCR: issues.append("OCR skipped (tesseract not installed) — bad-page/keyword checks disabled")
    # static sections
    STATIC_THRESH=1.2  # mean abs gray diff on 480x300; tune
    for s in secs:
        # cards are intentionally low-motion; only flag tool sections by name heuristic
        if s["name"] not in ("title","end","dryrun","intro","outro","arch","architecture","cover","section") and s["avg_motion"]<STATIC_THRESH:
            issues.append(f"section '{s['name']}' looks STATIC (avg_motion={s['avg_motion']}, max={s['max_motion']}) — likely a screenshot, not a live view")
    blurry=[s["name"] for s in secs if s["avg_sharpness"]<40]
    if blurry: issues.append(f"possibly blurry sections (low sharpness): {blurry}")

    aud_stats=audio_stats(path) if aud else None
    if aud_stats:
        if aud_stats["overall_db"]<-32: issues.append(f"audio quiet (overall {aud_stats['overall_db']} dB)")
        if aud_stats["longest_silence_s"]>=4: issues.append(f"long silent gap {aud_stats['longest_silence_s']}s (gaps {aud_stats['silence_gaps'][:6]})")

    score=100
    score-=40 if not aud else 0
    score-=10*sum(1 for i in issues if "STATIC" in i)
    score-=15 if bad_any else 0
    score-=10 if blank_frames else 0
    score-=8 if missing else 0
    score-=6*len(blurry)
    if aud_stats and aud_stats["longest_silence_s"]>=4: score-=6
    score=max(0,score)

    report={"video":path,"duration_s":round(dur,1),"has_audio":aud,"fps_sampled":fps,
            "score":score,"issues":issues,"sections":secs,"audio":aud_stats,
            "expected":expect,"missing_keywords":missing}
    with open(out,"w") as f: json.dump(report,f,indent=2)

    # human-readable
    print(f"\n=== DEMO QA: {os.path.basename(path)} ===")
    print(f"duration {report['duration_s']}s  audio={aud}  SCORE={score}/100")
    if secs:
        print("\nsection            motion(avg/max)  sharp   bad")
        for s in secs:
            print(f"  {s['name']:<16} {s['avg_motion']:>5}/{s['max_motion']:<5}    {s['avg_sharpness']:>6}  {len(s['bad_frames'])}")
    if aud_stats:
        print(f"\naudio: {aud_stats['overall_db']}dB  longest_silence={aud_stats['longest_silence_s']}s")
    print("\nISSUES:" if issues else "\nNo issues found.")
    for i in issues: print("  -",i)
    print(f"\nreport -> {out}")
    sys.exit(0 if score>=80 and not any('STATIC' in i or 'bad page' in i or 'NO AUDIO' in i for i in issues) else 2)

if __name__=="__main__":
    main()
