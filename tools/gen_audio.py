#!/usr/bin/env python3
"""Gera TODOS os sons e músicas do LogicBot por síntese (sem amostras de terceiros).

Uso:  python3 tools/gen_audio.py      (requer numpy e scipy)
Saída: assets/audio/*.wav  — 22.050 Hz, mono, 16 bits. Licença: mesma do projeto.
"""
import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)  # semente fixa: os arquivos saem sempre iguais


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, d=0.2, curve=4.0):
    x = np.arange(n) / SR
    e = np.minimum(1.0, x / max(a, 1e-4)) * np.exp(-curve * np.maximum(0, x - a) / max(d, 1e-4))
    return e


def lp(x, f):
    b, a = butter(2, min(f / (SR / 2), 0.99), "low")
    return lfilter(b, a, x)


def hp(x, f):
    b, a = butter(2, min(f / (SR / 2), 0.99), "high")
    return lfilter(b, a, x)


def bp(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band")
    return lfilter(b, a, x)


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def sweep(f0, f1, d, wave="sine"):
    tt = t(d)
    f = f0 * (f1 / f0) ** (tt / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if wave == "square":
        return np.sign(np.sin(ph))
    return np.sin(ph)


def reverb(x, tail=0.6, mix=0.25):
    ir = noise(tail) * np.exp(-6 * t(tail) / tail)
    ir = lp(ir, 5000)
    wet = np.convolve(x, ir)[: len(x) + int(SR * tail)]
    dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
    return dry + mix * wet / (np.max(np.abs(wet)) + 1e-9) * np.max(np.abs(x))


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fade = min(len(x), int(SR * 0.004))
    x[-fade:] *= np.linspace(1, 0, fade)
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def tone(freq, d, wave="sine", a=0.01, dec=0.3, curve=3.0):
    tt = t(d)
    ph = 2 * np.pi * freq * tt
    if wave == "saw":
        w = 2 * ((freq * tt) % 1.0) - 1
    elif wave == "square":
        w = np.sign(np.sin(ph)) * 0.6
    elif wave == "tri":
        w = 2 * np.abs(2 * ((freq * tt) % 1.0) - 1) - 1
    else:
        w = np.sin(ph)
    return w * env(len(tt), a, dec, curve)


def note(n):  # n = semitons a partir de A4 (440 Hz)
    return 440.0 * 2 ** (n / 12)


# ------------------------------------------------------------------ efeitos de combate

def make_sfx():
    d = 0.22
    body = sweep(140, 45, d) * env(int(SR * d), 0.002, 0.08)
    crack = lp(noise(d), 3500) * env(int(SR * d), 0.001, 0.03, 6)
    save("soco", mix(body * 1.0, crack * 0.7))

    d = 0.55
    body = sweep(110, 35, d) * env(int(SR * d), 0.002, 0.15)
    crack = lp(noise(d), 6000) * env(int(SR * d), 0.001, 0.06, 5)
    metal = sum(np.sin(2 * np.pi * f * t(d)) * env(int(SR * d), 0.001, 0.25, 4) * g for f, g in [(310, 0.4), (787, 0.3), (1431, 0.2)])
    save("soco_forte", reverb(mix(body, crack * 0.8, metal * 0.5), 0.5, 0.3))

    d = 0.4
    clank = sum(np.sin(2 * np.pi * f * t(d)) * env(int(SR * d), 0.001, dd, 4) * g
                for f, g, dd in [(523, 0.5, 0.3), (1307, 0.4, 0.2), (2093, 0.3, 0.15), (3320, 0.2, 0.1)])
    click = hp(noise(d), 2000) * env(int(SR * d), 0.0005, 0.01, 8)
    save("bloqueio", reverb(mix(clank, click * 0.6), 0.4, 0.25), 0.8)

    d = 0.3
    w = noise(d)
    out = np.zeros_like(w)
    seg = 8
    for i in range(seg):  # banda subindo = sensação de movimento
        a, b = i * len(w) // seg, (i + 1) * len(w) // seg
        lo = 300 + 2200 * i / seg
        out[a:b] = bp(w, lo, lo * 2.2)[a:b]
    save("esquiva", out * np.sin(np.pi * t(d) / d) ** 2, 0.6)

    d = 0.5
    ch = sweep(180, 950, d, "saw") * (0.6 + 0.4 * np.sin(2 * np.pi * 18 * t(d)))
    save("carga", lp(ch, 2500) * np.minimum(1, t(d) / 0.05) * np.exp(-0.5 * t(d)), 0.55)

    d = 0.8
    zap = sweep(1400, 90, d, "square") * env(int(SR * d), 0.002, 0.25)
    boom = sweep(80, 30, d) * env(int(SR * d), 0.003, 0.3)
    hiss = lp(noise(d), 4000) * env(int(SR * d), 0.002, 0.2)
    save("disparo", reverb(mix(lp(zap, 3000) * 0.5, boom, hiss * 0.5), 0.6, 0.35))

    d = 0.4
    crackle = noise(d) * (rng.uniform(0, 1, int(SR * d)) > 0.93)
    fz = sweep(600, 120, d, "square") * env(int(SR * d), 0.005, 0.2)
    save("sem_energia", mix(lp(crackle, 5000) * 0.8, lp(fz, 1500) * 0.4), 0.6)

    d = 1.6
    boom = sweep(70, 25, d) * env(int(SR * d), 0.003, 0.6, 3)
    rumble = lp(noise(d), 300) * env(int(SR * d), 0.01, 0.8, 3)
    save("nocaute", reverb(mix(boom, rumble * 0.8), 1.0, 0.4))


# ------------------------------------------------------------------ interface e vinhetas

def make_ui():
    save("ui_clique", mix(tone(1800, 0.06, "sine", 0.001, 0.02, 6), hp(noise(0.03), 3000) * env(int(SR * 0.03), 0.0005, 0.005, 8) * 0.3), 0.5)
    save("ui_hover", tone(2400, 0.04, "sine", 0.001, 0.015, 6), 0.25)

    def arpeggio(notes, step, d_note, wave="tri", gain=0.8):
        total = step * len(notes) + d_note
        out = np.zeros(int(SR * total))
        for i, n in enumerate(notes):
            s = tone(note(n), d_note, wave, 0.005, d_note * 0.5, 3)
            a = int(SR * i * step)
            out[a:a + len(s)] += s
        return reverb(out, 0.8, 0.3)

    save("round", arpeggio([-12, -5], 0.18, 0.5, "saw"), 0.6)
    save("lutem", arpeggio([0, 4, 7, 12], 0.06, 0.45, "saw"), 0.7)
    save("vitoria", arpeggio([0, 4, 7, 12, 16, 19, 24], 0.09, 0.6), 0.75)
    save("derrota", arpeggio([7, 3, 0, -5, -9], 0.16, 0.7), 0.7)
    save("conquista", arpeggio([12, 16, 19, 24, 28, 31], 0.05, 0.5, "sine"), 0.6)
    save("nivel", arpeggio([0, 7, 12, 16, 19, 24, 31], 0.07, 0.7, "sine"), 0.7)


# ------------------------------------------------------------------ músicas (loops)

def make_music(name, bpm, drums, bars=8):
    beat = 60.0 / bpm
    total = beat * 4 * bars
    n = int(SR * total)
    out = np.zeros(n + SR)
    prog = [(-12, [0, 3, 7]), (-16, [-4, 0, 3]), (-9, [-9, -5, -2]), (-14, [-2, 2, 5])]  # Am F C G
    for bar in range(bars):
        root, chord = prog[bar % 4]
        bar_t = bar * 4 * beat
        for e in range(8):  # baixo em colcheias
            s = tone(note(root - 12 + (12 if e % 4 == 3 else 0)), beat * 0.48, "saw", 0.005, 0.12, 4)
            s = lp(s, 700)
            a = int(SR * (bar_t + e * beat / 2))
            out[a:a + len(s)] += s * 0.5
        pad = sum(tone(note(c), beat * 4, "tri", 0.3, 2.0, 0.6) for c in chord)
        a = int(SR * bar_t)
        out[a:a + len(pad)] += lp(pad, 1800) * 0.22
        arp = [chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[1] + 12]
        for e in range(16 if drums else 8):
            step = beat / 4 if drums else beat / 2
            s = tone(note(arp[e % 4]), step * 0.9, "square", 0.002, 0.06, 5)
            a = int(SR * (bar_t + e * step))
            out[a:a + len(s)] += lp(s, 3000) * (0.12 if drums else 0.08)
        if drums:
            for b in range(4):
                k = sweep(120, 40, 0.18) * env(int(SR * 0.18), 0.001, 0.06)
                a = int(SR * (bar_t + b * beat))
                out[a:a + len(k)] += k * 0.8
                if b % 2 == 1:
                    sn = bp(noise(0.15), 1500, 6000) * env(int(SR * 0.15), 0.001, 0.04, 5)
                    out[a:a + len(sn)] += sn * 0.35
                for h in range(2):
                    hh = hp(noise(0.04), 7000) * env(int(SR * 0.04), 0.0005, 0.01, 6)
                    a2 = int(SR * (bar_t + b * beat + h * beat / 2 + beat / 4))
                    out[a2:a2 + len(hh)] += hh * 0.15
    tail = out[n:]
    out = out[:n]
    out[: len(tail)] += tail  # o "rabo" volta para o começo: loop sem emenda
    save(name, out, 0.55)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_sfx()
    make_ui()
    make_music("musica_batalha", 128, True)
    make_music("musica_menu", 92, False)
    print("Sons gerados em", os.path.abspath(OUT))
