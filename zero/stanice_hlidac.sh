#!/system/bin/sh
# Hlidac v TELEFONU. Nasazuje ho Zero pres adb do /data/local/tmp a spousti
# odpojene (setsid), takze prezije vytazeni kabelu. Bezi jako uid shell.
#
# Kazdou sekundu se podiva, jestli je USB pripojene k hostiteli (configured=true).
# Po GRACE sekundach bez hostitele vrati puvodni nastaveni ulozene v
# settings global stanice_orig_* a skonci. Kratke bliknuti kabelu prezije.
GRACE=10
PIDF=/data/local/tmp/stanice_hlidac.pid
LOG=/data/local/tmp/stanice_hlidac.log

echo $$ > $PIDF
echo "$(date '+%m-%d %H:%M:%S') start pid $$" >> $LOG

usb_host() {
    dumpsys usb 2>/dev/null | grep -q '^ *configured=true'
}

orig() { settings get global stanice_orig_$1 | tr -d '\r'; }

vratit() {
    echo "$(date '+%m-%d %H:%M:%S') USB $GRACE s pryc - vracim nastaveni" >> $LOG
    s=$(orig size);     [ "$s" = "reset" ] || [ "$s" = "null" ] && wm size reset     || wm size "$s"
    d=$(orig density);  [ "$d" = "reset" ] || [ "$d" = "null" ] && wm density reset  || wm density "$d"
    v=$(orig timeout);  [ "$v" = "null" ] || settings put system screen_off_timeout "$v"
    v=$(orig stayon);   [ "$v" = "null" ] || settings put global stay_on_while_plugged_in "$v"
    v=$(orig jasmode);  [ "$v" = "null" ] || settings put system screen_brightness_mode "$v"
    v=$(orig jas);      [ "$v" = "null" ] || settings put system screen_brightness "$v"
    v=$(orig rotace);   [ "$v" = "null" ] || settings put system accelerometer_rotation "$v"
    v=$(orig userrot);  [ "$v" = "null" ] || settings put system user_rotation "$v"
    for k in aktivni orig_size orig_density orig_timeout orig_stayon orig_jasmode orig_jas orig_rotace orig_userrot; do
        settings delete global stanice_$k >/dev/null 2>&1
    done
    echo "$(date '+%m-%d %H:%M:%S') vraceno: $(wm size | tr -d '\r' | tr '\n' ' ')" >> $LOG
}

n=0
while true; do
    if usb_host; then
        [ $n -gt 0 ] && echo "$(date '+%m-%d %H:%M:%S') USB zpet po $n s" >> $LOG
        n=0
    else
        n=$((n+1))
        [ $n -eq 1 ] && echo "$(date '+%m-%d %H:%M:%S') USB pryc, cekam $GRACE s" >> $LOG
    fi
    if [ $n -ge $GRACE ]; then
        vratit
        rm -f $PIDF
        exit 0
    fi
    # kdyz znacka zmizela (napr. rucni vratit.sh), neni co hlidat
    [ "$(settings get global stanice_aktivni | tr -d '\r')" = "1" ] || { rm -f $PIDF; exit 0; }
    sleep 1
done
