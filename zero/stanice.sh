#!/bin/bash
# Smycka stanice (Zero, systemd sluzba na tty1).
# Ceka na jakykoli Android po USB -> pripravi profil (jednou, idempotentne)
# -> nasadi do telefonu hlidac, ktery po 10 s bez kabelu vse vrati
# -> zrcadli pres scrcpy na HDMI -> po odpojeni ceka na dalsi.
export HOME=/home/pi
export SDL_VIDEODRIVER=kmsdrm
LOG=/home/pi/stanice.log
source /home/pi/stanice_lib.sh

adb start-server >/dev/null 2>&1
log "stanice start"

while true; do
    SER=$(prvni_zarizeni)
    if [ -z "$SER" ]; then
        UNAUTH=$(adb devices | awk 'NR>1 && $2=="unauthorized" {print $1; exit}')
        [ -n "$UNAUTH" ] && log "zarizeni $UNAUTH ceka na povoleni ladeni v telefonu"
        sleep 2
        continue
    fi
    MODEL=$(sh_ getprop ro.product.model)

    if je_aktivni; then
        log "$SER ($MODEL) uz je v profilu stanice (bliknuti kabelu / restart)"
    else
        pripravit
    fi
    nasadit_hlidac

    # kazdou minutu overit, ze hlidac v telefonu zije; kdyz ne, nasadit znovu
    ( while sleep 60; do hlidac_zije || { log "hlidac nezije, nasazuji znovu"; nasadit_hlidac; }; done ) &
    WD=$!

    log "zrcadlim $SER ($MODEL)"
    scrcpy -s "$SER" --verbosity=info \
        --max-size 1024 --max-fps 20 --video-bit-rate 2M \
        --stay-awake --window-borderless --window-x=0 --window-y=0 --window-width=1366 --window-height=768 \
        --capture-orientation=@90 \
        --audio-codec=opus --audio-bit-rate=64K \
        >> "$LOG" 2>&1
    RC=$?
    kill $WD 2>/dev/null; wait $WD 2>/dev/null
    log "scrcpy skoncil (kod $RC), cekam na dalsi zarizeni"
    sleep 2
done
