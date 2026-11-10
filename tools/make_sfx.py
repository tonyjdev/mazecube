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
    # Puente colgante que pierde estabilidad: crujido de madera (tono grave
    # que tiembla y baja, con roce).
    save("creak", mix(tone(190, 0.32, "bell", attack=0.03, decay=0.14, sweep_to=150, vibrato=0.06),
                      noise(0.3, decay=0.1, lowpass=0.2, volume=0.35, attack=0.02)), peak=0.45)
    # Puente que se cae: chasquido de madera y tablones que se alejan.
    snap = [noise(0.06, decay=0.015, lowpass=0.9), tone(260, 0.2, decay=0.05, sweep_to=140, volume=0.8)]
    for i in range(7):
        snap.append(offset(mix(tone(320 - i * 25, 0.12, "bell", decay=0.04, volume=0.55 - i * 0.06),
                               noise(0.08, decay=0.02, lowpass=0.4, volume=0.4 - i * 0.04)), 0.08 + i * 0.09))
    save("collapse", mix(*snap), peak=0.8)
    # Dash: arrastre rápido (ruido que sube y se corta) con un golpe seco al
    # final.
    drag = []
    last = 0.0
    n = int(0.16 * RATE)
    for i in range(n):
        t = i / n
        cutoff = 0.1 + 0.5 * t
        last += cutoff * (rng.uniform(-1, 1) - last)
        drag.append(last * (t ** 0.5) * (1.0 - t ** 4))
    save("dash", mix(drag, offset(tone(150, 0.1, decay=0.025, sweep_to=100, volume=0.7), 0.13)), peak=0.6)
    # Pisotón: golpe grave y fuerte contra el suelo con retumbo y polvo.
    save("stomp", mix(tone(65, 0.55, decay=0.18, sweep_to=38), tone(130, 0.2, decay=0.05, sweep_to=70, volume=0.6),
                      noise(0.45, decay=0.14, lowpass=0.2, volume=0.8), noise(0.05, decay=0.01, lowpass=0.9, volume=0.5)),
         peak=0.9)
    # Perseguidor reventado (criatura orgánica): golpe húmedo y grave,
    # salpicadura y burbujas que suben de tono, como una explosión en agua.
    splash = [tone(85, 0.3, decay=0.09, sweep_to=50), noise(0.35, decay=0.1, lowpass=0.18, volume=0.9),
              noise(0.04, decay=0.01, lowpass=0.6, volume=0.5)]
    for i in range(14):
        f = rng.uniform(280, 900)
        splash.append(offset(tone(f, 0.05, decay=0.025, sweep_to=f * rng.uniform(1.6, 2.4),
                                  volume=rng.uniform(0.25, 0.5)), 0.03 + rng.uniform(0, 0.38)))
    for i in range(6):
        splash.append(offset(noise(0.06, decay=0.02, lowpass=0.12, volume=0.4), 0.08 + i * 0.06))
    save("splat", mix(*splash), peak=0.75)
    # Enemigo sintético roto (patrullero y obstáculo): chasquido de rotura y
    # esquirlas de cristal y metal que tintinean al caer.
    shards = [noise(0.05, decay=0.012, lowpass=1.0), tone(1900, 0.2, "bell", decay=0.07, volume=0.5),
              tone(2650, 0.25, "bell", decay=0.09, volume=0.4), tone(180, 0.1, decay=0.03, sweep_to=110, volume=0.5)]
    for i in range(16):
        start = 0.02 + rng.uniform(0, 0.5) ** 1.4
        f = rng.uniform(2200, 6200)
        shards.append(offset(mix(tone(f, 0.12, "bell", decay=0.035, volume=rng.uniform(0.15, 0.4)),
                                 noise(0.015, decay=0.004, lowpass=1.0, volume=0.25)), start))
    save("shatter", mix(*shards), peak=0.7)
    # Teletransporte (al final para no cambiar el azar de los anteriores).
    # Ida: zumbido que sube de tono con trémolo y destellos que se apagan,
    # como si el cubo se deshiciera en luz.
    hum = []
    n = int(1.0 * RATE)
    phase = 0.0
    for i in range(n):
        t = i / n
        f = 180 + 700 * t ** 1.6
        phase += 2 * math.pi * f / RATE
        trem = 0.6 + 0.4 * math.sin(2 * math.pi * (6 + 18 * t) * i / RATE)
        env = min(1.0, t / 0.08) * (1.0 - t ** 3)
        hum.append((math.sin(phase) + 0.3 * math.sin(2 * phase)) * trem * env * 0.6)
    sparkle = [offset(tone(rng.uniform(1800, 4200), 0.18, "bell", decay=0.06, volume=rng.uniform(0.15, 0.3)),
                      0.15 + i * 0.07 + rng.uniform(0, 0.04)) for i in range(11)]
    save("teleport", mix(hum, *sparkle, noise(1.0, decay=0.5, lowpass=0.05, volume=0.25, attack=0.4)), peak=0.6)
    # Llegada: barrido que baja y se asienta en una nota clara con eco.
    arrive = [tone(1400, 0.45, "sine", attack=0.02, decay=0.2, sweep_to=520, volume=0.6),
              offset(tone(523.25, 0.7, "bell", decay=0.3, volume=0.7), 0.25),
              offset(tone(784.0, 0.6, "bell", decay=0.25, volume=0.4), 0.3),
              offset(tone(523.25, 0.5, "bell", decay=0.2, volume=0.25), 0.5),
              noise(0.4, decay=0.15, lowpass=0.08, volume=0.3, attack=0.05)]
    save("teleport_in", mix(*arrive), peak=0.55)
    # Pinchos (al final para no cambiar el azar de los anteriores): las
    # lanzas salen de golpe con un siseo metálico corto y chocan contra el
    # tope con un tañido de acero (parciales inarmónicos que se apagan
    # deprisa) y un golpe seco del mecanismo.
    swish = []
    last = 0.0
    n = int(0.07 * RATE)
    for i in range(n):
        t = i / n
        last += 0.85 * (rng.uniform(-1, 1) - last)
        swish.append(last * t ** 1.5)
    clang = [offset(tone(f, 0.45, "sine", attack=0.001, decay=d, volume=v), 0.065)
             for f, d, v in ((1870, 0.16, 0.55), (2960, 0.11, 0.45), (4410, 0.07, 0.35),
                             (6120, 0.05, 0.25), (1245, 0.2, 0.3))]
    for k in range(3):
        clang.append(offset(tone(rng.uniform(2500, 5200), 0.2, "sine", attack=0.001, decay=0.04,
                                 volume=0.2), 0.066 + k * 0.006))
    thud = offset(mix(tone(150, 0.12, decay=0.03, sweep_to=90, volume=0.7),
                      noise(0.04, decay=0.008, lowpass=0.7, volume=0.6)), 0.06)
    save("spikes", mix([v * 0.5 for v in swish], *clang, thud), peak=0.7)
    # Cañón láser (al final para no cambiar el azar de los anteriores).
    # Aviso: un pitido muy corto y agudo por cada parpadeo de las luces (el
    # silencio entre pitidos lo deja el propio parpadeo).
    save("laser_beep", mix(tone(2350, 0.045, "triangle", attack=0.002, volume=0.8),
                           tone(4700, 0.045, "sine", attack=0.002, volume=0.15)), peak=0.35)
    # Disparo: «piu» que baja de tono deprisa, con un armónico y un soplo.
    zap = [tone(2600, 0.2, "square", attack=0.001, decay=0.07, sweep_to=320, volume=0.5),
           tone(5200, 0.12, "sine", attack=0.001, decay=0.04, sweep_to=900, volume=0.35),
           noise(0.08, decay=0.02, lowpass=0.9, volume=0.25)]
    save("laser", mix(*zap), peak=0.55)
    # Choque: chisporroteo de chasquidos agudos que se apagan.
    crackle = [noise(0.05, decay=0.012, lowpass=0.95, volume=0.7)]
    for k in range(9):
        start = 0.008 + k * 0.022 + rng.uniform(0, 0.012)
        crackle.append(offset(noise(0.03, decay=0.005, lowpass=0.95, volume=0.65 - k * 0.06), start))
        crackle.append(offset(tone(rng.uniform(3000, 6500), 0.03, "sine", attack=0.001, decay=0.006,
                                   volume=0.3 - k * 0.025), start))
    save("laser_hit", mix(*crackle), peak=0.45)
    # Cañón de bombas (al final para no cambiar el azar de los anteriores).
    # Disparo: estampido grave y hueco de mortero con un soplo de pólvora.
    boom = [tone(70, 0.5, decay=0.14, sweep_to=42, volume=1.0),
            tone(140, 0.25, decay=0.06, sweep_to=80, volume=0.5),
            noise(0.35, decay=0.09, lowpass=0.12, volume=0.9),
            noise(0.05, decay=0.012, lowpass=0.7, volume=0.5)]
    save("mortar", mix(*boom), peak=0.8)
    # Bote de la bomba: golpe metálico pesado y apagado contra el suelo.
    save("bomb_bounce", mix(tone(110, 0.18, decay=0.045, sweep_to=75, volume=0.9),
                            tone(620, 0.12, "bell", attack=0.001, decay=0.03, volume=0.2),
                            noise(0.06, decay=0.015, lowpass=0.35, volume=0.6)), peak=0.6)
    # Mecha: siseo chisporroteante que dura lo que la cuenta atrás más corta.
    fizz = [noise(2.0, decay=4.0, lowpass=0.9, volume=0.25, attack=0.05)]
    for k in range(60):
        start = rng.uniform(0.0, 1.95)
        fizz.append(offset(noise(0.012, decay=0.003, lowpass=1.0, volume=rng.uniform(0.3, 0.7)), start))
    fuse = mix(*fizz)
    fade = int(0.3 * RATE)
    for i in range(fade):
        fuse[-fade + i] *= 1.0 - i / fade
    save("bomb_fuse", fuse, peak=0.3)
    # Explosión: estallido muy grave y retumbante, con un rugido sordo que se
    # apaga despacio y restos que crepitan apagados.
    # (Con armónicos: el altavoz del móvil no da los graves de verdad, pero así
    # el oído los sigue notando.)
    blast = [tone(42, 1.4, "rich", decay=0.45, sweep_to=22, volume=1.0),
             tone(65, 0.7, "rich", decay=0.18, sweep_to=32, volume=0.7),
             noise(1.6, decay=0.5, lowpass=0.03, volume=1.2),
             noise(0.3, decay=0.06, lowpass=0.18, volume=0.5),
             noise(0.04, decay=0.01, lowpass=0.5, volume=0.4)]
    for k in range(14):
        start = 0.1 + rng.uniform(0, 0.8) ** 1.3
        blast.append(offset(noise(0.02, decay=0.005, lowpass=0.35, volume=rng.uniform(0.08, 0.18)), start))
    save("bomb_explode", mix(*blast), peak=0.9)
    # Cubito dorado cogido: destello brillante, arpegio de campanas que sube y
    # un brillo agudo que tintinea.
    sparkle = [offset(tone(f, 0.9, "bell", decay=0.3, volume=0.8), i * 0.05)
               for i, f in enumerate((1318.5, 1568.0, 1975.5, 2637.0))]
    sparkle.append(tone(660, 0.5, "triangle", decay=0.15, sweep_to=1320, volume=0.4))
    for k in range(10):
        sparkle.append(offset(tone(rng.uniform(3000, 4200), 0.12, decay=0.03, volume=0.25), 0.1 + k * 0.045))
    save("collect", mix(*sparkle), peak=0.6)
    # Estrella conseguida en la pantalla final: campanada clara con un brillo
    # (el juego sube el tono de una estrella a la siguiente).
    save("star", mix(tone(880, 0.9, "bell", decay=0.32), tone(1760, 0.6, "bell", decay=0.18, volume=0.5),
                     tone(2640, 0.3, decay=0.06, volume=0.25),
                     noise(0.05, decay=0.012, lowpass=0.9, volume=0.25)), peak=0.6)
    # Estrella no conseguida: golpe apagado y grave.
    save("star_miss", mix(tone(180, 0.25, "triangle", decay=0.07, sweep_to=120),
                          noise(0.08, decay=0.02, lowpass=0.15, volume=0.4)), peak=0.45)
    print("Sonidos generados en", OUT)


if __name__ == "__main__":
    main()
