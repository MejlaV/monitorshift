#!/bin/bash
# Rucni priprava pripojeneho Androidu pro stanici (normalne to dela stanice.sh sama).
#   bash ~/pripravit.sh [SERIOVE]
LOG=/dev/stdout
source /home/pi/stanice_lib.sh
SER=${1:-$(prvni_zarizeni)}
[ -z "$SER" ] && { echo "Zadne autorizovane zarizeni:"; adb devices; exit 1; }
if je_aktivni; then echo "$SER uz je v profilu stanice."; else pripravit; fi
nasadit_hlidac
echo "--- stav ---"; sh_ wm size; sh_ wm density
sudo systemctl restart stanice.service 2>/dev/null
