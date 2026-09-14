#!/bin/bash
# Spanek / probuzeni stanice. Prepina stav; volatelne z tlacitka (GPIO) nebo rucne:
#   bash ~/spanek.sh            prepnout
#   bash ~/spanek.sh spat       uspat
#   bash ~/spanek.sh vzbudit    probudit
#
# spat:    displej telefonu VYPNOUT (ne jen ztlumit), zamek nezacvakne (lock_after_timeout=max),
#          Wi-Fi telefonu vypnout (YouTube nic nestahuje), zrcadleni zastavit, HDMI do DPMS off
#          -> monitor jde sam do standby. Nabijeni bezi dal.
# vzbudit: HDMI zpet, Wi-Fi zpet, displej zapnout, zrcadleni spustit.
STAV=/run/user/$(id -u)/stanice_spi
[ -d "$(dirname "$STAV")" ] || STAV=/tmp/stanice_spi
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
    A settings put secure lock_screen_lock_after_timeout 2147483647
    A svc wifi disable
    A input keyevent KEYCODE_SLEEP
    sleep 1
    hdmi 3
    touch "$STAV"
}

vzbudit() {
    log "probouzim ($SER)"
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
