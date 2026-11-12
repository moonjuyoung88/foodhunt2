#!/usr/bin/env python3
"""효과음 합성기 (외부 음원 없이 직접 만든 8비트풍 사운드). assets/sfx/*.wav 생성."""
import math
import struct
import wave
from pathlib import Path

SR = 22050
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'sfx'


def tone(freqs, dur, vol=0.5, shape='square', decay=6.0):
    n = int(SR * dur)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = freqs[0] + (freqs[1] - freqs[0]) * t
        ph += f / SR
        x = ph % 1.0
        if shape == 'square':
            v = 1.0 if x < 0.5 else -1.0
        elif shape == 'tri':
            v = 4 * abs(x - 0.5) - 1
        else:
            v = math.sin(2 * math.pi * x)
        env = math.exp(-decay * t) * min(1.0, i / (SR * 0.004))
        out.append(v * vol * env)
    return out


def seq(notes, shape='square', vol=0.45):
    out = []
    for f, d in notes:
        out += tone((f, f), d, vol, shape, 4.0)
    return out


def save(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32000)) for s in samples))


save('pop1', tone((620, 880), 0.07, 0.4, 'tri', 5))
save('pop2', tone((700, 990), 0.07, 0.4, 'tri', 5))
save('pop3', tone((790, 1110), 0.07, 0.4, 'tri', 5))
save('launch', tone((260, 620), 0.13, 0.4, 'square', 3))
save('tray', tone((420, 210), 0.16, 0.4, 'square', 4))
save('full', seq([(880, 0.05), (1320, 0.09)], 'tri', 0.5))
save('tap', tone((500, 500), 0.04, 0.35, 'tri', 8))
save('nope', tone((160, 120), 0.12, 0.4, 'square', 5))
save('boost', seq([(523, 0.06), (784, 0.06), (1047, 0.12)], 'tri', 0.5))
save('win', seq([(523, 0.1), (659, 0.1), (784, 0.1), (1047, 0.1), (784, 0.08), (1047, 0.3)], 'square', 0.4))
save('fail', seq([(392, 0.14), (330, 0.14), (262, 0.14), (196, 0.34)], 'square', 0.4))
print('ok')
