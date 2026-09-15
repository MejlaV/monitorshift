#!/usr/bin/env python3
"""Tlacitko spanku stanice. Mezi GPIO3 (pin 5) a GND (pin 6) - zadny rezistor,
pull-up je vnitrni. Uvolneni tlacitka po stisku prepne spanek/probuzeni (spanek.sh).
Cte pin primo pres lgpio (gpiozero na soucasnem jadre udalosti nedorucovalo).
Bezi jako systemd sluzba tlacitko.service."""
import subprocess, time, lgpio

PIN = 3
SKRIPT = "/home/pi/spanek.sh"
DEBOUNCE = 0.05      # s - kontakt musi byt stabilni
MIN_MEZERA = 3.0     # s - ochrana proti dvojkliku, prepnuti trva par sekund

h = lgpio.gpiochip_open(0)
lgpio.gpio_claim_input(h, PIN, lgpio.SET_PULL_UP)

stav = 1                     # 1 = nestisknuto (pull-up), 0 = stisknuto
posledni_prepnuti = 0.0
zmena_od = None
while True:
    v = lgpio.gpio_read(h, PIN)
    if v != stav:
        if zmena_od is None:
            zmena_od = time.monotonic()
        elif time.monotonic() - zmena_od >= DEBOUNCE:
            stav = v
            zmena_od = None
            if stav == 1:    # uvolneno po stisku
                ted = time.monotonic()
                if ted - posledni_prepnuti >= MIN_MEZERA:
                    posledni_prepnuti = ted
                    print("stisk -> spanek.sh", flush=True)
                    subprocess.Popen(["bash", SKRIPT])
    else:
        zmena_od = None
    time.sleep(0.02)
