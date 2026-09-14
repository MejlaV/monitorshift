#!/bin/bash
# Rucni navrat pripojeneho Androidu do normalu (hlidac v telefonu to dela sam 10 s po odpojeni).
#   bash ~/vratit.sh [SERIOVE]
LOG=/dev/stdout
source /home/pi/stanice_lib.sh
SER=${1:-$(prvni_zarizeni)}
[ -z "$SER" ] && { echo "Zadne autorizovane zarizeni:"; adb devices; exit 1; }
vratit
echo "--- stav ---"; sh_ wm size; sh_ wm density
