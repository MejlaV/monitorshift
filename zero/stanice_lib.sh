#!/bin/bash
# Spolecne funkce stanice (Zero). Pouziva stanice.sh, pripravit.sh, vratit.sh.
# Vsechno pres adb, bez rootu. Stav a originaly zije v telefonu:
#   settings global stanice_aktivni = 1
#   settings global stanice_orig_{size,density,timeout,stayon,jasmode,jas,rotace,userrot}
MON_W=768; MON_H=1366            # monitor na vysku (Elo 1502L otoceny)
CIL_DP=600                       # sirka v dp: >=600 prepne Chrome/YouTube do tabletoveho rozlozeni; vetsi cislo = mensi prvky
HLIDAC_SRC=/home/pi/stanice_hlidac.sh
HLIDAC_DST=/data/local/tmp/stanice_hlidac.sh
LOG=${LOG:-/home/pi/stanice.log}

log() { echo "$(date '+%H:%M:%S') $*" >> "$LOG"; }

sh_() { adb -s "$SER" shell "$@" | tr -d '\r'; }
sget() { sh_ settings get "$1" "$2"; }
sput() { adb -s "$SER" shell settings put "$1" "$2" "$3" >/dev/null; }

# prvni autorizovane zarizeni, nebo prazdno
prvni_zarizeni() { adb devices | awk 'NR>1 && $2=="device" {print $1; exit}'; }

je_aktivni() { [ "$(sget global stanice_aktivni)" = "1" ]; }

# Ulozi originaly do telefonu a nastavi profil stanice. Navrat: 0 ok, 2 tablet (nastaveno jen bez rozliseni).
pripravit() {
    local model pw ph pd ov od
    model=$(sh_ getprop ro.product.model)
    read pw ph < <(sh_ wm size | awk -F'[ x]' '/Physical/ {print $3, $4}')
    pd=$(sh_ wm density | awk '/Physical/ {print $3}')
    ov=$(sh_ wm size | awk '/Override/ {print $3}');    [ -z "$ov" ] && ov=reset
    od=$(sh_ wm density | awk '/Override/ {print $3}'); [ -z "$od" ] && od=reset
    log "pripravuji $SER ($model) fyz ${pw}x${ph}@${pd}"

    # originaly (jen pokud tam jeste nejsou - po bliknuti kabelu je nechat)
    if [ "$(sget global stanice_orig_size)" = "null" ]; then
        sput global stanice_orig_size    "$ov"
        sput global stanice_orig_density "$od"
        sput global stanice_orig_timeout "$(sget system screen_off_timeout)"
        sput global stanice_orig_stayon  "$(sget global stay_on_while_plugged_in)"
        sput global stanice_orig_jasmode "$(sget system screen_brightness_mode)"
        sput global stanice_orig_jas     "$(sget system screen_brightness)"
        sput global stanice_orig_rotace  "$(sget system accelerometer_rotation)"
        sput global stanice_orig_userrot "$(sget system user_rotation)"
    fi

    # spolecna cast profilu
    sput system screen_off_timeout 2147483647
    sput global stay_on_while_plugged_in 15
    sput system screen_brightness_mode 0
    sput system screen_brightness 1
    sput system accelerometer_rotation 1      # otaci telefon podle g-senzoru, Zero ma @90
    sput system show_touches 0
    sput system pointer_location 0
    adb -s "$SER" shell input keyevent KEYCODE_WAKEUP >/dev/null

    if [ "$pw" -gt "$ph" ]; then
        log "  prirozena orientace na sirku (tablet) - rozliseni nechavam"
        sput global stanice_aktivni 1
        return 2
    fi
    local nd=$(( MON_W * 160 / CIL_DP ))
    adb -s "$SER" shell wm size ${MON_W}x${MON_H} >/dev/null
    adb -s "$SER" shell wm density $nd >/dev/null
    sput global stanice_aktivni 1
    log "  profil: ${MON_W}x${MON_H} @ ${nd} dpi, originaly ulozeny"
    return 0
}

# Vrati originaly (rucni cesta; hlidac v telefonu dela totez sam).
vratit() {
    local v
    v=$(sget global stanice_orig_size);    { [ "$v" = reset ] || [ "$v" = null ]; } && adb -s "$SER" shell wm size reset    >/dev/null || adb -s "$SER" shell wm size "$v" >/dev/null
    v=$(sget global stanice_orig_density); { [ "$v" = reset ] || [ "$v" = null ]; } && adb -s "$SER" shell wm density reset >/dev/null || adb -s "$SER" shell wm density "$v" >/dev/null
    v=$(sget global stanice_orig_timeout); [ "$v" = null ] || sput system screen_off_timeout "$v"
    v=$(sget global stanice_orig_stayon);  [ "$v" = null ] || sput global stay_on_while_plugged_in "$v"
    v=$(sget global stanice_orig_jasmode); [ "$v" = null ] || sput system screen_brightness_mode "$v"
    v=$(sget global stanice_orig_jas);     [ "$v" = null ] || sput system screen_brightness "$v"
    v=$(sget global stanice_orig_rotace);  [ "$v" = null ] || sput system accelerometer_rotation "$v"
    v=$(sget global stanice_orig_userrot); [ "$v" = null ] || sput system user_rotation "$v"
    for k in aktivni orig_size orig_density orig_timeout orig_stayon orig_jasmode orig_jas orig_rotace orig_userrot; do
        adb -s "$SER" shell settings delete global stanice_$k >/dev/null 2>&1
    done
    adb -s "$SER" shell "kill \$(cat /data/local/tmp/stanice_hlidac.pid 2>/dev/null) 2>/dev/null; rm -f /data/local/tmp/stanice_hlidac.pid" >/dev/null 2>&1
    log "vraceno $SER: $(sh_ wm size | tr '\n' ' ')"
}

# Zamykaci obrazovka Samsungu je pres scrcpy cerna (FLAG_SECURE), gesto se zadava na
# telefonu. Kdyz je zamceno, rozsvitit panel telefonu; po odemknuti zpet na minimum.
JAS_ZAMEK=${JAS_ZAMEK:-160}
hlidat_zamek() {
    local stav minule=""
    while sleep 3; do
        stav=$(adb -s "$SER" shell dumpsys trust 2>/dev/null | grep -o -m1 'deviceLocked=[01]')
        [ -z "$stav" ] && continue
        if [ "$stav" != "$minule" ]; then
            if [ "$stav" = "deviceLocked=1" ]; then
                sput system screen_brightness $JAS_ZAMEK; log "zamceno - panel telefonu rozsvicen pro gesto"
            else
                sput system screen_brightness 1;          log "odemceno - panel telefonu na minimum"
            fi
            minule=$stav
        fi
    done
}

hlidac_zije() {
    local pid
    pid=$(sh_ cat /data/local/tmp/stanice_hlidac.pid 2>/dev/null)
    [ -n "$pid" ] && adb -s "$SER" shell "kill -0 $pid 2>/dev/null && echo ANO" | grep -q ANO
}

nasadit_hlidac() {
    adb -s "$SER" push "$HLIDAC_SRC" "$HLIDAC_DST" >/dev/null 2>&1
    adb -s "$SER" shell "chmod 755 $HLIDAC_DST; kill \$(cat /data/local/tmp/stanice_hlidac.pid 2>/dev/null) 2>/dev/null; setsid nohup sh $HLIDAC_DST </dev/null >/dev/null 2>&1 &" >/dev/null 2>&1
    sleep 1
    if hlidac_zije; then log "  hlidac v telefonu bezi (pid $(sh_ cat /data/local/tmp/stanice_hlidac.pid))"; else log "  hlidac se NESPUSTIL"; return 1; fi
}
