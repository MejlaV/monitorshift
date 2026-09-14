#!/usr/bin/env python3
"""Tlacitko spanku stanice. Mezi GPIO3 (pin 5) a GND (pin 6) - zadny rezistor,
pull-up je vnitrni. Kazde stisknuti prepne spanek/probuzeni (spanek.sh).
GPIO3 je navic pin, ktery probudi vypnute Pi (halt), kdyby se to nekdy hodilo.
Bezi jako systemd sluzba tlacitko.service."""
import subprocess, time
from gpiozero import Button

PIN = 3
SKRIPT = "/home/pi/spanek.sh"
posledni = 0.0

def stisk():
    global posledni
    ted = time.monotonic()
    if ted - posledni < 2.0:          # ochrana proti dvojkliku, prepnuti trva par sekund
        return
    posledni = ted
    subprocess.Popen(["bash", SKRIPT])

Button(PIN, pull_up=True, bounce_time=0.05).when_released = stisk
while True:
    time.sleep(3600)
