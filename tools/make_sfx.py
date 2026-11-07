#!/usr/bin/env python3
"""Sintetiza los efectos de sonido de Maze Cube en audio/sfx/*.wav.

Todos los sonidos se generan aquí a partir de ondas simples, ruido y
envolventes (no hay grabaciones externas). WAV mono de 16 bits a 22 050 Hz.

Uso (desde la raíz del repositorio): python3 tools/make_sfx.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "audio" / "sfx"
rng = random.Random(1107)


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def mix(*tracks):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def offset(track, seconds):
    return silence(seconds) + track


def tone(freq, seconds, wave_shape="sine", attack=0.005, decay=None, volume=1.0, sweep_to=None,
         vibrato=0.0):
    """Nota con envolvente: ataque lineal y caída exponencial (decay = tiempo
    en que baja a ~37%) o mantenida hasta el final con un pequeño desvanecido."""
    n = int(seconds * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq if sweep_to is None else freq + (sweep_to - freq) * (i / n)
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * 7 * t)
        phase += 2 * math.pi * f / RATE
        if wave_shape == "sine":
            v = math.sin(phase)
        elif wave_shape == "square":
            v = 0.6 if math.sin(phase) >= 0 else -0.6
        elif wave_shape == "triangle":
            v = 2 / math.pi * math.asin(math.sin(phase))
        else:
            v = math.sin(phase) + 0.4 * math.sin(2 * phase) + 0.2 * math.sin(3 * phase)
            v *= 0.6
        env = min(1.0, t / attack) if attack > 0 else 1.0
        if decay:
            env *= math.exp(-t / decay)
        else:
            env *= min(1.0, (seconds - t) / 0.03)
        out.append(v * env * volume)
    return out


def noise(seconds, decay=0.1, volume=1.0, lowpass=0.5, attack=0.002):
    """Ruido blanco filtrado (paso bajo de un polo: 1 = sin filtrar)."""
    n = int(seconds * RATE)
    out, last = [], 0.0
    for i in range(n):
        t = i / RATE
        last += lowpass * (rng.uniform(-1, 1) - last)
        env = min(1.0, t / attack) * math.exp(-t / decay)
        out.append(last * env * volume)
    return out


def normalize(track, peak=0.85):
    top = max(abs(v) for v in track) or 1.0
    return [v * peak / top for v in track]


def save(name, track, peak=0.85):
    OUT.mkdir(parents=True, exist_ok=True)
    data = normalize(track, peak)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in data))


def main():
    # Vuelco del cubo: golpe sordo y corto sobre el suelo.
    save("roll", mix(tone(95, 0.12, decay=0.03, sweep_to=70), noise(0.06, decay=0.012, lowpass=0.25, volume=0.5)),
         peak=0.5)
    # Rebote contra una pared: golpe de madera.
    save("bounce", mix(tone(210, 0.15, decay=0.035, sweep_to=160), tone(420, 0.1, decay=0.02, volume=0.5),
                       noise(0.05, decay=0.01, lowpass=0.5, volume=0.6)), peak=0.7)
    # Giro descartado: dos pitidos suaves que bajan.
    save("reject", mix(tone(620, 0.07, "triangle", decay=0.05),
                       offset(tone(440, 0.09, "triangle", decay=0.06), 0.07)), peak=0.45)
    # Llave cogida: campanitas en arpegio.
    save("key", mix(*[offset(tone(f, 0.5, "bell", decay=0.18), i * 0.07)
                      for i, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0))]), peak=0.6)
    # Puerta abierta: chasquido de cerradura y la puerta hundiéndose.
    save("door", mix(tone(900, 0.05, "square", decay=0.012, volume=0.5),
                     offset(noise(0.6, decay=0.35, lowpass=0.08), 0.04),
                     offset(tone(120, 0.6, decay=0.3, sweep_to=55), 0.04)), peak=0.7)
    # Golpe a un muro destructible: crujido de piedra.
    save("crack", mix(noise(0.18, decay=0.05, lowpass=0.6), tone(140, 0.15, decay=0.04, sweep_to=90)), peak=0.75)
    # Muro roto: derrumbe (varios golpes de piedra que se apagan).
    rubble = [noise(0.5, decay=0.18, lowpass=0.3), tone(80, 0.5, decay=0.15, sweep_to=45)]
    for i in range(9):
        rubble.append(offset(noise(0.12, decay=0.03, lowpass=0.5, volume=0.6 - i * 0.05), 0.05 + i * 0.06))
    save("break", mix(*rubble), peak=0.85)
    # Botón pulsado: clic doble.
    save("button", mix(tone(1400, 0.03, "square", decay=0.008), noise(0.02, decay=0.004, lowpass=0.9),
                       offset(tone(900, 0.04, "square", decay=0.01), 0.06)), peak=0.55)
    # Barrotes moviéndose: metal que se desliza y resuena.
    save("bars", mix(noise(0.4, decay=0.2, lowpass=0.6, volume=0.5),
                     tone(1530, 0.5, decay=0.15, volume=0.4), tone(2290, 0.5, decay=0.1, volume=0.3),
                     tone(980, 0.5, decay=0.2, volume=0.3)), peak=0.5)
    # Power up de velocidad: barrido hacia arriba con vibrato.
    save("powerup", mix(tone(350, 0.35, "square", sweep_to=1250, vibrato=0.03, volume=0.6),
                        offset(tone(1250, 0.15, "triangle", decay=0.08), 0.33)), peak=0.5)
    # Media vuelta: soplido de humo.
    whoosh = []
    last = 0.0
    n = int(0.35 * RATE)
    for i in range(n):
        t = i / n
        cutoff = 0.05 + 0.25 * math.sin(math.pi * t)
        last += cutoff * (rng.uniform(-1, 1) - last)
        whoosh.append(last * math.sin(math.pi * t))
    save("reverse", whoosh, peak=0.55)
    # Explosión del cubo: estallido con retumbo grave.
    save("explode", mix(noise(1.0, decay=0.25, lowpass=0.35), tone(70, 1.0, decay=0.3, sweep_to=35),
                        noise(0.08, decay=0.02, lowpass=1.0, volume=0.6)), peak=0.9)
    # Meta: fanfarria corta.
    notes = [(523.25, 0.0), (659.25, 0.11), (783.99, 0.22), (1046.5, 0.33)]
    fanfare = [offset(tone(f, 0.16 if i < 3 else 0.6, "triangle", decay=0.12 if i < 3 else 0.3), t)
               for i, (f, t) in enumerate(notes)]
    fanfare.append(offset(tone(1318.5, 0.6, "triangle", decay=0.3, volume=0.5), 0.33))
    save("goal", mix(*fanfare), peak=0.6)
    # Perseguidor que te ha visto: alarma de dos notas.
    save("alert", mix(tone(880, 0.1, "square", decay=0.06), offset(tone(1175, 0.14, "square", decay=0.08), 0.1)),
         peak=0.45)
    # Interfaz: clic de botón.
    save("click", mix(tone(1800, 0.03, "sine", decay=0.008), noise(0.015, decay=0.003, lowpass=0.8, volume=0.4)),
         peak=0.4)
    # Caída al vacío: silbido que baja de tono con un soplo de aire.
    save("fall", mix(tone(1100, 0.7, "triangle", attack=0.02, decay=0.45, sweep_to=180, vibrato=0.015),
                     noise(0.7, decay=0.4, lowpass=0.12, volume=0.35, attack=0.05)), peak=0.45)
    print("Sonidos generados en", OUT)


if __name__ == "__main__":
    main()
