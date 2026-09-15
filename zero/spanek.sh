#!/bin/bash
# Spanek / probuzeni stanice. Prepina stav; volatelne z tlacitka (GPIO) nebo rucne:
#   bash ~/spanek.sh            prepnout
#   bash ~/spanek.sh spat       uspat
#   bash ~/spanek.sh vzbudit    probudit
#
# spat:    panel telefonu VYPNOUT, ale telefon NEUSPAT - Samsung pri KEYCODE_SLEEP
#          zamkne bez ohledu na nastaveni casovace. Proto panel vypina scrcpy
#          (--turn-screen-off bez videa a okna), ktere behem spanku bezi a drzi ho
#          vypnuty; Android zustava Awake, zamek nezacvakne. Wi-Fi telefonu vypnout
#          (zapomenuty YouTube nic nestahuje), zrcadleni zastavit, HDMI do DPMS off
#          -> monitor jde sam do standby. Nabijeni bezi dal.
# vzbudit: scrcpy-drzak ukoncit (panel se zapne), HDMI zpet, Wi-Fi zpet, zrcadleni spustit.
RUN=/run/user/$(id -u); [ -d "$RUN" ] || RUN=/tmp
STAV=$RUN/stanice_spi
PIDF=$RUN/stanice_drzak.pid
LOG=/home/pi/stanice.log
log() { echo "$(date '+%H:%M:%S') spanek: $*" >> "$LOG"; }

SER=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')
A() { [ -n "$SER" ] && adb -s "$SER" shell "$@" >/dev/null 2>&1; }

hdmi() {   # 0 = zapnout, 3 = vypnout (DRM DPMS)
    local id
    id=$(modetest -M vc4 2>/dev/null | awk '/^[0-9]+.*HDMI-A-1/ {print $1; exit}')
    [ -n "$id" ] && sudo modetest -M vc4 -w "$id:DPMS:$1" >/dev/null 2>&1
}

spat() {
    log "usinam ($SER)"
    sudo systemctl stop stanice.service
    A svc wifi disable
    if [ -n "$SER" ]; then
        scrcpy -s "$SER" --turn-screen-off --stay-awake --no-video --no-audio --no-window \
            >> "$LOG" 2>&1 &
        echo $! > "$PIDF"
    fi
    sleep 1
    hdmi 3
    touch "$STAV"
}

vzbudit() {
    log "probouzim ($SER)"
    [ -f "$PIDF" ] && { kill "$(cat "$PIDF")" 2>/dev/null; rm -f "$PIDF"; }
    sleep 1
    hdmi 0
    A svc wifi enable
    A input keyevent KEYCODE_WAKEUP
    rm -f "$STAV"
    sudo systemctl start stanice.service
}

case "${1:-}" in
    spat)    spat ;;
    vzbudit) vzbudit ;;
    *)       if [ -e "$STAV" ]; then vzbudit; else spat; fi ;;
esac
