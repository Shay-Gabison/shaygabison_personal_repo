# kokoro_synth.py — natural offline TTS. usage: kokoro_synth.py <voice> <txtfile> <out.wav> [speed]
import sys, numpy as np, soundfile as sf
from kokoro import KPipeline
voice = sys.argv[1]; text = open(sys.argv[2]).read().strip(); out = sys.argv[3]
speed = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
pipe = KPipeline(lang_code='a')  # 'a' = American English; 'b' = British
chunks = [a for _,_,a in pipe(text, voice=voice, speed=speed)]
audio = np.concatenate(chunks) if chunks else np.zeros(1)
sf.write(out, audio, 24000)
