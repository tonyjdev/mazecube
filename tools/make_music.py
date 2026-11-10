#!/usr/bin/env python3
"""Compone y sintetiza la música de Maze Cube en audio/music/*.ogg.

Como los efectos de sonido (make_sfx.py), todo se genera aquí: no hay
grabaciones ni muestras externas. Cada tema es un bucle sin cortes:

- menu: el menú (tranquilo, marimba y pads).
- zone1 … zone5: una por zona del mapa de niveles:
  1. El mundo de los cubos: alegre y saltarín.
  2. Las tierras salvajes: aventurero, con flauta y tambores.
  3. El mundo desconocido: misterioso, campanas y pads amplios.
  4. Los territorios corrompidos: tenso, sierras desafinadas y pulso grave.
  5. El núcleo enemigo: intenso, rápido y con arpegios de semicorcheas.

Cómo se hace:
- Una canción es una lista de secciones (intro, A, B…) de varios compases,
  cada una con su progresión de acordes (grados de la escala).
- Las capas (bajo, arpegio, melodía, batería…) se generan a partir de los
  acordes con patrones propios de cada tema; la melodía se compone con un
  motivo de un compás que se repite y varía (semilla fija, así que siempre
  sale igual). Cada capa suena solo en las secciones que se indiquen.
- Los instrumentos se sintetizan de forma aditiva o con FM; la reverb es una
  convolución con una respuesta sintética y hay un eco estéreo.
- La intro (sección «I») suena solo al empezar: el bucle vuelve al final de
  ella. Su punto de vuelta, en segundos, se guarda en audio/music/loops.json
  (Music lo pone como loop_offset). La cola de la reverb del final se suma
  ahí para que el bucle no tenga corte.

Requiere numpy y ffmpeg (con libvorbis). Uso (desde la raíz del repositorio):
    uv run --with numpy python tools/make_music.py [nombre ...]
"""
import json
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

SR = 32000
OUT = Path(__file__).resolve().parent.parent / "audio" / "music"
TAIL = 4.0  # segundos de cola que se pliegan al principio del bucle
NYQ = SR / 2

SCALES = {
    "major": [0, 2, 4, 5, 7, 9, 11],
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "harmonic": [0, 2, 3, 5, 7, 8, 11],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
}


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def times(n):
    return np.arange(n) / SR


# --- Instrumentos -----------------------------------------------------------
# Cada uno devuelve una nota mono: instrumento(frecuencia, duración_s, velocidad).

def env_ar(n, attack, release, hold_n):
    """Ataque lineal, sostenido hasta hold_n y caída lineal de `release` s."""
    e = np.ones(n)
    a = min(n, max(1, int(attack * SR)))
    e[:a] = np.linspace(0, 1, a, endpoint=False)
    r = max(1, int(release * SR))
    end = min(n, hold_n + r)
    if hold_n < n:
        e[hold_n:end] *= np.linspace(1, 0, end - hold_n)
        e[end:] = 0
    return e


def additive(f, n, weight, vib=None, phase0=0.0, max_k=40):
    t = times(n)
    if vib is not None:
        phase = 2 * np.pi * np.cumsum(f * (1 + vib(t))) / SR
    else:
        phase = 2 * np.pi * f * t
    out = np.zeros(n)
    for k in range(1, max_k + 1):
        if k * f >= NYQ * 0.92:
            break
        w = weight(k, t)
        if np.isscalar(w) and w == 0:
            continue
        out += w * np.sin(k * phase + phase0 * k)
    return out


def pad(f, d, v):
    rel = 1.4
    n = int((d + rel) * SR)
    out = np.zeros(n)
    for cents, ph in ((-8, 0.0), (8, 1.3), (0, 2.1)):
        ff = f * 2 ** (cents / 1200)
        out += additive(ff, n, lambda k, t: (1 / k) * np.exp(-k / 5.0), phase0=ph, max_k=18)
    return out * env_ar(n, 0.7, rel, int(d * SR)) * v * 0.22


def airpad(f, d, v):
    """Pad suave y hueco (armónicos impares, con un leve trémolo)."""
    rel = 2.0
    n = int((d + rel) * SR)
    t = times(n)
    out = np.zeros(n)
    for cents in (-6, 6):
        ff = f * 2 ** (cents / 1200)
        out += additive(ff, n, lambda k, t: (1 / k ** 1.5) if k % 2 else 0.12 / k, max_k=12)
    trem = 1 + 0.15 * np.sin(2 * np.pi * 0.35 * t)
    return out * trem * env_ar(n, 1.2, rel, int(d * SR)) * v * 0.22


def pluck(f, d, v):
    rel = 0.25
    n = int((min(d, 1.2) + rel + 0.6) * SR)
    out = additive(f, n, lambda k, t: (1 / k ** 1.1) * np.exp(-t * (2.0 + 1.1 * k)), max_k=24)
    return out * env_ar(n, 0.003, rel, int((min(d, 1.2) + 0.6) * SR)) * v * 0.5


def marimba(f, d, v):
    n = int(1.2 * SR)
    t = times(n)
    index = 2.2 * np.exp(-t * 22)
    body = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * 4.0 * f * t))
    body += 0.25 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 10)
    env = np.exp(-t * 4.5) * np.minimum(1, t / 0.002)
    return body * env * v * 0.42


def bell(f, d, v):
    n = int(3.0 * SR)
    t = times(n)
    index = 2.4 * np.exp(-t * 2.5)
    body = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * 3.5 * f * t))
    body += 0.3 * np.sin(2 * np.pi * 2.76 * f * t) * np.exp(-t * 3)
    env = np.exp(-t * 1.6) * np.minimum(1, t / 0.002)
    return body * env * v * 0.28


def bass(f, d, v, bright=1.0):
    rel = 0.06
    n = int((d + rel) * SR)
    cut = lambda t: 0.35 + 0.5 * (1 - np.exp(-t * 7)) / bright
    out = additive(f, n, lambda k, t: (1 / k) * np.exp(-(k - 1) * cut(t)), max_k=20)
    out += 0.6 * np.sin(2 * np.pi * f * times(n))
    return out * env_ar(n, 0.004, rel, int(d * SR)) * v * 0.42


def bass_bright(f, d, v):
    return bass(f, d, v, bright=2.2)


def lead(f, d, v):
    """Cuadrada suave con vibrato que entra poco a poco."""
    rel = 0.12
    n = int((d + rel) * SR)
    vib = lambda t: 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.18) / 0.3, 0, 1)
    out = additive(f, n, lambda k, t: (1 / k) * np.exp(-k / 9.0) if k % 2 else 0.0, vib=vib, max_k=25)
    return out * env_ar(n, 0.015, rel, int(d * SR)) * v * 0.3


def flute(f, d, v):
    rel = 0.1
    n = int((d + rel) * SR)
    vib = lambda t: 0.007 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.15) / 0.3, 0, 1)
    amps = {1: 1.0, 2: 0.32, 3: 0.12, 4: 0.05}
    out = additive(f, n, lambda k, t: amps.get(k, 0.0), vib=vib, max_k=4)
    breath = fft_filter(np.random.default_rng(int(f)).standard_normal(n), f * 0.8, f * 3.5) * 0.06
    env = env_ar(n, 0.04, rel, int(d * SR))
    return (out + breath) * env * v * 0.34


def saw_lead(f, d, v):
    """Sierras desafinadas, algo ásperas (territorios corrompidos)."""
    rel = 0.15
    n = int((d + rel) * SR)
    out = np.zeros(n)
    for cents, ph in ((-14, 0.0), (0, 0.9), (13, 2.0)):
        ff = f * 2 ** (cents / 1200)
        out += additive(ff, n, lambda k, t: (1 / k) * np.exp(-k / 12.0), phase0=ph, max_k=22)
    out = np.tanh(out * 1.6) / 1.6
    return out * env_ar(n, 0.02, rel, int(d * SR)) * v * 0.18


def arp_square(f, d, v):
    """Notas cortas de cuadrada filtrada (arpegios rápidos)."""
    n = int((d + 0.08) * SR)
    t = times(n)
    out = additive(f, n, lambda k, t: (1 / k) * np.exp(-k * (0.2 + 2.5 * t)) if k % 2 else 0.0, max_k=21)
    return out * env_ar(n, 0.002, 0.06, int(d * SR)) * np.exp(-t * 3) * v * 0.3


# --- Batería ----------------------------------------------------------------

def fft_filter(x, lo=None, hi=None, slope=1.0):
    """Filtro suave por FFT: paso alto en `lo` y paso bajo en `hi` (Hz)."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    gain = np.ones_like(freqs)
    if lo:
        gain *= 1 / (1 + (lo / np.maximum(freqs, 1)) ** (4 * slope))
    if hi:
        gain *= 1 / (1 + (freqs / hi) ** (4 * slope))
    return np.fft.irfft(spec * gain, len(x))


_noise = np.random.default_rng(42)


def kick(v, low=45.0, punch=1.0):
    n = int(0.45 * SR)
    t = times(n)
    f = low + (150 - low) * np.exp(-t * 28)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7)
    click = fft_filter(_noise.standard_normal(n), 1500, 6000) * np.exp(-t * 300) * 0.4
    return np.tanh((body + click) * 1.5 * punch) * v * 0.9


def snare(v):
    n = int(0.3 * SR)
    t = times(n)
    noise = fft_filter(_noise.standard_normal(n), 900, 7000) * np.exp(-t * 18)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25)
    return (noise * 0.7 + tone * 0.6) * v * 0.6


def clap(v):
    n = int(0.3 * SR)
    t = times(n)
    noise = fft_filter(_noise.standard_normal(n), 1000, 5000)
    env = np.zeros(n)
    for off in (0.0, 0.011, 0.022):
        env += np.exp(-np.maximum(t - off, 0) * 60) * (t >= off)
    env += np.exp(-t * 14) * 0.5
    return noise * env * v * 0.35


def hat(v, open_=False):
    n = int((0.35 if open_ else 0.08) * SR)
    t = times(n)
    noise = fft_filter(_noise.standard_normal(n), 7000, None)
    return noise * np.exp(-t * (9 if open_ else 55)) * v * 0.22


def shaker(v):
    n = int(0.09 * SR)
    t = times(n)
    noise = fft_filter(_noise.standard_normal(n), 4000, 11000)
    return noise * np.sin(np.pi * np.minimum(t / 0.09, 1)) ** 2 * v * 0.13


def tom(v, f=110.0):
    n = int(0.5 * SR)
    t = times(n)
    freq = f * (1 + 0.6 * np.exp(-t * 20))
    body = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 6)
    return np.tanh(body * 1.3) * v * 0.55


def rim(v):
    n = int(0.06 * SR)
    t = times(n)
    return (np.sin(2 * np.pi * 1700 * t) * 0.6 + fft_filter(_noise.standard_normal(n), 2000, 8000) * 0.4) \
        * np.exp(-t * 90) * v * 0.3


DRUMS = {
    "K": kick, "S": snare, "C": clap, "h": hat, "o": lambda v: hat(v, True), "s": shaker,
    "t": lambda v: tom(v, 95.0), "T": lambda v: tom(v, 140.0), "r": rim,
    "B": lambda v: kick(v, 38.0, 1.6),
}


# --- Composición ------------------------------------------------------------

class Song:
    def __init__(self, name, bpm, root, scale, sections, seed):
        self.name = name
        self.bpm = bpm
        self.root = root
        self.scale = SCALES[scale]
        self.sections = sections  # [(letra, [grados por compás])]
        self.rng = np.random.default_rng(seed)
        self.beat = 60.0 / bpm
        self.bars = []  # (letra, grado, índice dentro de la sección)
        for letter, chords in sections:
            for i, degree in enumerate(chords):
                self.bars.append((letter, degree, i))
        self.length = len(self.bars) * 4 * self.beat
        self.loop_start = sum(1 for b in self.bars if b[0] == "I") * 4 * self.beat
        self.layers = []  # (instrumento, notas, pan, ganancia, reverb, eco)

    def note(self, degree, octave=0):
        """Nota MIDI del grado `degree` de la escala (puede pasar de 7)."""
        o, d = divmod(degree, 7)
        return self.root + self.scale[d] + 12 * (o + octave)

    def chord(self, degree, size=3):
        return [degree + 2 * i for i in range(size)]

    def add(self, instrument, notes, pan=0.0, gain=1.0, reverb=0.25, echo=0.0):
        self.layers.append((instrument, notes, pan, gain, reverb, echo))

    def bars_in(self, letters):
        return [(i, b) for i, b in enumerate(self.bars) if b[0] in letters]

    # Generadores de capas: devuelven [(inicio_en_pulsos, duración_en_pulsos, midi, velocidad)].

    def pad_layer(self, letters, octave=0, size=3, bars_per_chord=1):
        notes = []
        for i, (letter, degree, k) in self.bars_in(letters):
            if k % bars_per_chord:
                continue
            for d in self.chord(degree, size):
                notes.append((i * 4, 4 * bars_per_chord - 0.1, self.note(d, octave), 0.8))
        return notes

    def bass_layer(self, letters, pattern, octave=-2):
        """pattern: lista de (pulso, duración, salto en grados, velocidad) por compás.
        El salto 7 es la octava; 4, la quinta."""
        notes = []
        for i, (letter, degree, k) in self.bars_in(letters):
            for beat, dur, step, vel in pattern:
                notes.append((i * 4 + beat, dur, self.note(degree + step, octave), vel))
        return notes

    def arp_layer(self, letters, order, step=0.5, octave=0, dur=None, vel=0.7, size=4):
        """Arpegio sobre el acorde: order indexa las notas del acorde (y +10 la octava)."""
        notes = []
        per_bar = int(4 / step)
        for i, (letter, degree, k) in self.bars_in(letters):
            tones = [self.note(d, octave) for d in self.chord(degree, size)]
            for j in range(per_bar):
                idx = order[j % len(order)]
                m = tones[idx % 10 % len(tones)] + (12 if idx >= 10 else 0)
                accent = 1.0 if j % (per_bar // 4 or 1) == 0 else 0.8
                notes.append((i * 4 + j * step, dur or step * 0.9, m, vel * accent))
        return notes

    def melody_layer(self, letters, rhythms, octave=1, seed=0, rest_end=True):
        """Melodía por frases de 4 compases: motivo, variación, motivo sobre el
        nuevo acorde y final en la fundamental. Misma letra = misma melodía."""
        notes = []
        motifs = {}
        for i, (letter, degree, k) in self.bars_in(letters):
            if letter not in motifs:
                rng = np.random.default_rng(seed + ord(letter))
                rhythm = rhythms[rng.integers(len(rhythms))]
                contour = [int(x) for x in rng.integers(-2, 3, len(rhythm))]
                var_rhythm = rhythms[rng.integers(len(rhythms))]
                var_contour = [int(x) for x in rng.integers(-2, 3, len(var_rhythm))]
                motifs[letter] = (rhythm, contour, var_rhythm, var_contour)
            rhythm, contour, var_rhythm, var_contour = motifs[letter]
            pos = k % 4
            last_phrase = (k // 4) % 2 == 1
            if pos == 3:
                # Final de frase: nota larga en la fundamental o la tercera.
                target = degree if last_phrase else degree + 2
                notes.append((i * 4, 2.5 if rest_end else 3.5, self.note(target, octave), 0.85))
                if not rest_end:
                    continue
                notes.append((i * 4 + 3, 0.9, self.note(target + 1, octave), 0.6))
                continue
            rh, co = (var_rhythm, var_contour) if pos == 1 else (rhythm, contour)
            current = degree + (4 if pos == 2 and last_phrase else 2 if pos == 2 else 0)
            for j, (beat, dur) in enumerate(rh):
                if j:
                    current += co[j]
                # Las notas fuertes caen en notas del acorde.
                if beat in (0, 2) and (current - degree) % 2:
                    current += 1 if co[j] >= 0 else -1
                current = max(degree - 3, min(degree + 9, current))
                vel = 0.9 if beat == int(beat) else 0.72
                notes.append((i * 4 + beat, dur, self.note(current, octave), vel))
        return notes

    def drum_layer(self, letters, patterns, fill=None, vel=1.0):
        """patterns: {voz: cadena de 16 pasos}, con mayúsculas fuertes ('X') y
        minúsculas suaves ('x'). Cada 8 compases (o al final de sección), `fill`."""
        hits = []
        last_of_section = {}
        for i, (letter, degree, k) in enumerate(self.bars):
            last_of_section[letter] = max(last_of_section.get(letter, 0), k)
        for i, (letter, degree, k) in self.bars_in(letters):
            use = patterns
            is_last = k == last_of_section[letter] or k % 8 == 7
            if fill and is_last:
                use = fill
            for voice, steps in use.items():
                for j, ch in enumerate(steps):
                    if ch in ".-":
                        continue
                    strength = 1.0 if ch.isupper() else 0.6
                    hits.append((i * 4 + j * 0.25, voice, strength * vel))
        return hits


# --- Mezcla -----------------------------------------------------------------

def render_song(song):
    total = int((song.length + TAIL) * SR)
    dry = np.zeros((2, total))
    rev_send = np.zeros((2, total))
    echo_send = np.zeros((2, total))
    rng = np.random.default_rng(7)

    def place(buf, sound, start, pan, gain):
        s = int(start * SR)
        if s >= total:
            return
        e = min(total, s + len(sound))
        theta = (pan + 1) * np.pi / 4
        buf[0, s:e] += sound[: e - s] * np.cos(theta) * gain
        buf[1, s:e] += sound[: e - s] * np.sin(theta) * gain

    for instrument, notes, pan, gain, reverb, echo in song.layers:
        if instrument == "drums":
            cache = {}
            for beat, voice, vel in notes:
                key = (voice, round(vel, 2))
                if key not in cache:
                    cache[key] = DRUMS[voice](vel)
                p = pan.get(voice, 0.0) if isinstance(pan, dict) else pan
                g = gain.get(voice, 1.0) if isinstance(gain, dict) else gain
                start = beat * song.beat
                sound = cache[key]
                place(dry, sound, start, p, g)
                place(rev_send, sound, start, p, g * (reverb if voice not in "KB" else reverb * 0.3))
            continue
        cache = {}
        for beat, dur, midi, vel in notes:
            key = (midi, round(dur, 3), round(vel, 2))
            if key not in cache:
                cache[key] = instrument(hz(midi), dur * song.beat, vel)
            sound = cache[key]
            # Un pelín tarde al azar, para que no suene mecánico.
            start = beat * song.beat + abs(rng.normal(0, 0.004))
            place(dry, sound, start, pan, gain)
            if reverb:
                place(rev_send, sound, start, pan, gain * reverb)
            if echo:
                place(echo_send, sound, start, pan, gain * echo)

    wet = reverb_fx(rev_send) + echo_fx(echo_send, song.beat * 0.75)
    mix = dry + wet
    # La cola del final suena al principio del bucle (al acabar la intro).
    # Para que la primera vez tampoco entre de golpe, el final del tema se
    # funde también en los últimos instantes de la intro (así la cola continúa
    # lo que ya sonaba en las dos pasadas).
    n = int(song.length * SR)
    start = int(song.loop_start * SR)
    lead_in = int(0.4 * SR)
    end_part = mix[:, n - lead_in: n].copy()
    mix[:, start: start + total - n] += mix[:, n:]
    mix[:, start - lead_in: start] += end_part * np.linspace(0, 1, lead_in) ** 2
    mix = mix[:, :n]
    # Al volver, lo que sigue es lo que sonaba justo antes del final de la
    # intro: un fundido corto hacia eso evita el chasquido del empalme.
    fade = int(0.05 * SR)
    w = np.sin(np.linspace(0, np.pi / 2, fade)) ** 2
    mix[:, n - fade:] = mix[:, n - fade:] * (1 - w) + mix[:, start - fade: start] * w
    return master(mix)


def reverb_fx(x, rt=2.2):
    n = int(rt * SR)
    t = times(n)
    rng = np.random.default_rng(3)
    out = np.zeros_like(x)
    for ch in range(2):
        bright = rng.standard_normal(n) * np.exp(-t * 6.9 / (rt * 0.45))
        dark = fft_filter(rng.standard_normal(n), None, 2500) * np.exp(-t * 6.9 / rt)
        ir = bright * 0.5 + dark
        ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
        ir /= np.sqrt(np.sum(ir ** 2))
        size = 1 << int(np.ceil(np.log2(x.shape[1] + n)))
        y = np.fft.irfft(np.fft.rfft(x[ch], size) * np.fft.rfft(ir, size), size)
        out[ch] = y[: x.shape[1]]
    return out * 0.9


def echo_fx(x, delay, feedback=0.42, repeats=6):
    out = np.zeros_like(x)
    d = int(delay * SR)
    src = fft_filter(x[0] + x[1], 300, 4500) * 0.5
    for r in range(1, repeats + 1):
        ch = r % 2  # rebota de un lado al otro
        shift = d * r
        if shift >= x.shape[1]:
            break
        out[ch, shift:] += src[: x.shape[1] - shift] * feedback ** r
    return out


def master(mix, target_rms=0.16):
    mix = fft_filter(mix[0], 28, None), fft_filter(mix[1], 28, None)
    mix = np.array(mix)
    rms = np.sqrt(np.mean(mix ** 2))
    mix *= target_rms / max(rms, 1e-9)
    # Limitador suave.
    return np.tanh(mix * 1.1) / np.tanh(1.1) * 0.95


def write_ogg(name, stereo):
    OUT.mkdir(parents=True, exist_ok=True)
    wav_path = OUT / f"{name}.tmp.wav"
    data = (np.clip(stereo.T, -1, 1) * 32767).astype("<i2")
    with wave.open(str(wav_path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis",
                    "-q:a", "3", str(OUT / f"{name}.ogg")], check=True)
    wav_path.unlink()


# --- Temas ------------------------------------------------------------------
# Ritmos de melodía de un compás: (pulso, duración).
R_CALM = [
    [(0, 1.5), (1.5, 0.5), (2, 2)],
    [(0, 1), (1, 1), (2, 1.5), (3.5, 0.5)],
    [(0, 0.5), (0.5, 0.5), (1, 1), (2, 2)],
    [(0, 2), (2, 1), (3, 1)],
]
R_BOUNCY = [
    [(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 1), (3, 0.5), (3.5, 0.5)],
    [(0, 0.75), (0.75, 0.25), (1, 0.5), (1.5, 0.5), (2, 1.5), (3.5, 0.5)],
    [(0, 1), (1, 0.5), (1.5, 0.5), (2, 0.5), (2.5, 0.5), (3, 1)],
    [(0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 1), (3, 1)],
]
R_DRIVE = [
    [(0, 0.5), (0.5, 0.25), (0.75, 0.25), (1, 0.5), (1.5, 0.5), (2, 0.75), (2.75, 0.25), (3, 1)],
    [(0, 0.25), (0.25, 0.25), (0.5, 0.5), (1, 1), (2, 0.5), (2.5, 0.5), (3, 0.5), (3.5, 0.5)],
    [(0, 1), (1, 0.25), (1.25, 0.25), (1.5, 0.5), (2, 1), (3, 0.5), (3.5, 0.5)],
]


def song_menu():
    prog_a = [0, 5, 3, 4] * 2           # I vi IV V
    prog_b = [3, 4, 2, 5, 3, 4, 0, 0]   # IV V iii vi IV V I I
    s = Song("menu", 88, 60, "major", [("I", [0, 3, 0, 3]), ("A", prog_a), ("B", prog_b), ("A", prog_a)],
             seed=11)
    s.add(pad, s.pad_layer("IAB", octave=-1, size=4), gain=0.7, reverb=0.5)
    s.add(marimba, s.arp_layer("IAB", [0, 2, 1, 3, 2, 1, 10, 2], step=0.5, octave=0, vel=0.55), pan=-0.3,
          gain=0.8, reverb=0.35, echo=0.25)
    s.add(bass, s.bass_layer("AB", [(0, 1.8, 0, 0.8), (2, 1, 4, 0.6), (3, 0.9, 7, 0.55)]), gain=0.8, reverb=0.05)
    s.add(bell, s.melody_layer("AB", R_CALM, octave=1, seed=3), pan=0.25, gain=0.75, reverb=0.45, echo=0.3)
    s.add("drums", s.drum_layer("AB", {"s": "xxXxxxXxxxXxxxXx", "r": "......X.......X."}), gain=0.8,
          pan={"s": 0.4, "r": -0.2}, reverb=0.2)
    return s


def song_zone1():
    prog_a = [0, 4, 5, 3] * 2           # I V vi IV
    prog_b = [3, 4, 0, 5, 1, 4, 0, 0]
    s = Song("zone1", 116, 67 - 12, "major",
             [("I", [0, 4, 0, 4]), ("A", prog_a), ("B", prog_b), ("A", prog_a), ("C", [3, 4, 5, 4])], seed=21)
    s.add(pad, s.pad_layer("IABC", octave=0, size=3), gain=0.45, reverb=0.4)
    s.add(pluck, s.arp_layer("IABC", [0, 1, 2, 10, 2, 1], step=0.5, octave=1, vel=0.5), pan=-0.35,
          gain=0.7, reverb=0.25, echo=0.2)
    s.add(bass_bright, s.bass_layer("ABC", [(0, 0.45, 0, 0.9), (1, 0.45, 7, 0.6), (1.5, 0.45, 0, 0.7),
                                           (2, 0.45, 4, 0.8), (3, 0.45, 7, 0.6), (3.5, 0.45, 4, 0.6)]),
          gain=0.8, reverb=0.05)
    s.add(lead, s.melody_layer("AB", R_BOUNCY, octave=1, seed=5), pan=0.15, gain=0.8, reverb=0.3, echo=0.2)
    s.add(marimba, s.melody_layer("C", R_BOUNCY, octave=1, seed=9), pan=0.2, gain=0.9, reverb=0.3)
    s.add("drums", s.drum_layer("ABC", {"K": "X.....x.X.......", "C": "....X.......X...",
                                        "h": "x.x.x.x.x.x.x.xo"},
                                fill={"K": "X.....x.X.......", "C": "....X.......X.X.", "t": "..........x.xxXX"}),
          gain={"K": 1.0, "C": 0.9, "h": 0.8, "t": 0.8}, pan={"h": 0.35, "t": -0.2}, reverb=0.15)
    s.add("drums", s.drum_layer("I", {"h": "x.x.x.x.x.x.x.x."}), gain=0.6, pan=0.35, reverb=0.15)
    return s


def song_zone2():
    prog_a = [0, 6, 3, 0, 0, 6, 4, 4]   # i bVII IV i (dórico)
    prog_b = [5, 6, 0, 0, 5, 6, 4, 4]
    s = Song("zone2", 120, 62 - 12, "dorian",
             [("I", [0, 0, 6, 6]), ("A", prog_a), ("B", prog_b), ("A", prog_a), ("C", [3, 3, 6, 6])], seed=31)
    s.add(pad, s.pad_layer("IABC", octave=0, size=3, bars_per_chord=1), gain=0.45, reverb=0.45)
    s.add(pluck, s.arp_layer("ABC", [0, 2, 1, 2, 0, 2, 10, 2], step=0.5, octave=1, vel=0.45), pan=0.4,
          gain=0.6, reverb=0.25, echo=0.15)
    s.add(bass, s.bass_layer("ABC", [(0, 0.7, 0, 0.9), (0.75, 0.25, 0, 0.6), (1.5, 0.5, 4, 0.7),
                                    (2, 0.7, 0, 0.85), (2.75, 0.25, 0, 0.6), (3.5, 0.5, 6, 0.65)]),
          gain=0.85, reverb=0.05)
    s.add(flute, s.melody_layer("AB", R_CALM + R_BOUNCY[:2], octave=1, seed=8), pan=-0.1, gain=0.85,
          reverb=0.45, echo=0.2)
    drums = {"t": "X..x..X...x.X...", "T": "..........X...x.", "s": "x.x.x.x.x.x.x.x.", "K": "X.......X.......",
             "r": "....X.......X..."}
    s.add("drums", s.drum_layer("ABC", drums, fill={**drums, "T": "........X.X.XXXX"}),
          gain={"t": 0.9, "T": 0.8, "s": 0.8, "K": 0.9, "r": 0.8}, pan={"t": -0.3, "T": 0.3, "s": 0.4, "r": -0.15},
          reverb=0.25)
    s.add("drums", s.drum_layer("I", {"t": "X.....X.....X..."}), gain=0.7, pan=-0.3, reverb=0.3)
    return s


def song_zone3():
    prog_a = [0, 0, 5, 5, 3, 3, 4, 4]   # i i VI VI iv iv v v (menor)
    prog_b = [5, 6, 0, 0, 3, 5, 4, 4]
    s = Song("zone3", 92, 64 - 12, "minor", [("I", [0, 0, 5, 5]), ("A", prog_a), ("B", prog_b), ("A", prog_a)],
             seed=41)
    s.add(airpad, s.pad_layer("IAB", octave=0, size=4, bars_per_chord=2), gain=0.8, reverb=0.6)
    s.add(bell, s.arp_layer("IAB", [0, 3, 2, 10, 1, 3, 2, 13], step=0.5, octave=1, vel=0.38), pan=0.35,
          gain=0.55, reverb=0.5, echo=0.35)
    s.add(bass, s.bass_layer("AB", [(0, 3.8, 0, 0.75)]), gain=0.75, reverb=0.1)
    s.add(lead, s.melody_layer("B", R_CALM, octave=1, seed=12), pan=-0.2, gain=0.55, reverb=0.55, echo=0.35)
    s.add(flute, s.melody_layer("A", R_CALM, octave=1, seed=2), pan=-0.25, gain=0.6, reverb=0.55, echo=0.3)
    s.add("drums", s.drum_layer("AB", {"K": "X.........X.....", "r": "........X.......",
                                       "s": "..x...x...x...x."}), gain={"K": 0.7, "r": 0.7, "s": 0.7},
          pan={"r": 0.3, "s": -0.35}, reverb=0.35)
    return s


def song_zone4():
    prog_a = [0, 0, 1, 1, 0, 0, 5, 4]   # i bII i … (frigio)
    prog_b = [5, 5, 1, 1, 3, 3, 4, 4]
    s = Song("zone4", 104, 61 - 12, "phrygian",
             [("I", [0, 0, 1, 1]), ("A", prog_a), ("B", prog_b), ("A", prog_a), ("C", [0, 1, 0, 1])], seed=51)
    s.add(pad, s.pad_layer("IABC", octave=-1, size=3), gain=0.5, reverb=0.5)
    s.add(bass, s.bass_layer("ABC", [(j * 0.5, 0.4, 0, 0.9 if j % 2 == 0 else 0.65) for j in range(8)]),
          gain=0.85, reverb=0.05)
    s.add(arp_square, s.arp_layer("IABC", [0, 1, 2, 1], step=0.25, octave=0, vel=0.4, size=3), pan=0.35,
          gain=0.55, reverb=0.2, echo=0.25)
    s.add(saw_lead, s.melody_layer("AB", R_CALM + R_DRIVE[:1], octave=1, seed=14), pan=-0.15, gain=0.9,
          reverb=0.4, echo=0.25)
    s.add(bell, s.melody_layer("C", R_CALM, octave=2, seed=6), pan=0.2, gain=0.5, reverb=0.6, echo=0.3)
    drums = {"K": "X.....X...X.....", "S": "....X.......X...", "h": "..x...x...x...x.", "r": "...........x..x."}
    s.add("drums", s.drum_layer("ABC", drums, fill={**drums, "t": "..........X.XtXT"}),
          gain={"K": 1.0, "S": 0.75, "h": 0.7, "r": 0.6, "t": 0.8, "T": 0.8},
          pan={"h": 0.3, "r": -0.3, "t": -0.25, "T": 0.25}, reverb=0.25)
    return s


def song_zone5():
    prog_a = [0, 0, 5, 5, 3, 3, 4, 4]   # i VI iv V (menor armónica)
    prog_b = [3, 4, 0, 5, 3, 4, 4, 4]
    s = Song("zone5", 132, 57 - 12, "harmonic",
             [("I", [0, 0, 5, 4]), ("A", prog_a), ("B", prog_b), ("A", prog_a), ("C", [5, 5, 4, 4])], seed=61)
    s.add(pad, s.pad_layer("ABC", octave=-1, size=3), gain=0.45, reverb=0.45)
    s.add(bass_bright, s.bass_layer("IABC", [(j * 0.5, 0.4, 7 if j % 4 == 3 else 0, 0.9 if j % 2 == 0 else 0.7)
                                            for j in range(8)]), gain=0.8, reverb=0.05)
    s.add(arp_square, s.arp_layer("IABC", [0, 1, 2, 10, 2, 1, 0, 1], step=0.25, octave=1, vel=0.38, size=3),
          pan=-0.35, gain=0.55, reverb=0.2, echo=0.2)
    s.add(saw_lead, s.melody_layer("AB", R_DRIVE, octave=1, seed=17), pan=0.1, gain=0.95, reverb=0.35, echo=0.2)
    s.add(lead, s.melody_layer("C", R_DRIVE, octave=1, seed=19), pan=0.2, gain=0.8, reverb=0.35, echo=0.2)
    drums = {"B": "X...X...X...X...", "C": "....X.......X...", "h": "xxXxxxXxxxXxxxXx", "o": "..............X."}
    s.add("drums", s.drum_layer("ABC", drums, fill={**drums, "S": "........x.xXXXXX"}),
          gain={"B": 0.95, "C": 0.85, "h": 0.6, "o": 0.6, "S": 0.7}, pan={"h": 0.3, "o": 0.3}, reverb=0.2)
    s.add("drums", s.drum_layer("I", {"B": "X...X...X...X...", "h": "..x...x...x...x."}), gain=0.8,
          pan={"h": 0.3}, reverb=0.2)
    return s


SONGS = {f.__name__[5:]: f for f in (song_menu, song_zone1, song_zone2, song_zone3, song_zone4, song_zone5)}


if __name__ == "__main__":
    names = sys.argv[1:] or list(SONGS)
    loops_path = OUT / "loops.json"
    loops = json.loads(loops_path.read_text()) if loops_path.exists() else {}
    for name in names:
        song = SONGS[name]()
        audio = render_song(song)
        write_ogg(name, audio)
        # Un cuarto de muestra más para que, al pasarlo a muestras, no caiga en la anterior.
        loops[name] = round((int(song.loop_start * SR) + 0.25) / SR, 7)
        loops_path.write_text(json.dumps(loops, indent=1, sort_keys=True) + "\n")
        print(f"{name}: {song.length:.1f} s, {len(song.bars)} compases a {song.bpm} ppm")
