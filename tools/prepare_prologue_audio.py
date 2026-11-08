"""Deterministic, original metallic chain clash for the scripted blackout."""
from pathlib import Path
import math
import random
import struct
import wave

random.seed(13)
rate = 44100
duration = 1.25
partials = [(1360, 0.36), (2137, 0.24), (3279, 0.18), (4871, 0.12), (7237, 0.06)]
samples = []
for index in range(int(rate * duration)):
    t = index / rate
    attack = min(1.0, t / 0.002)
    tone = sum(amp * math.sin(2 * math.pi * hz * t) * math.exp(-t * (4 + hz / 1700)) for hz, amp in partials)
    noise = (random.random() * 2 - 1) * 0.3 * math.exp(-t * 95)
    value = (tone + noise) * attack * 0.7
    samples.append(struct.pack('<h', int(max(-1, min(1, value)) * 32767)))
output = Path(__file__).resolve().parents[1] / 'assets/prologue/chain_clash.wav'
with wave.open(str(output), 'wb') as sound:
    sound.setnchannels(1)
    sound.setsampwidth(2)
    sound.setframerate(rate)
    sound.writeframes(b''.join(samples))
print(output)
