#!/bin/bash
# MonitorShift installer for a fresh Raspberry Pi OS Lite (trixie / bookworm).
# Run as the default user (pi) on the Pi itself:
#     bash install.sh
# Idempotent - safe to run again. Log: ~/monitorshift-install.log
set -u
SCRCPY_VERSION=${SCRCPY_VERSION:-v4.1}
HERE=$(cd "$(dirname "$0")" && pwd)
exec > >(tee -a ~/monitorshift-install.log) 2>&1
echo "=== MonitorShift install $(date) ==="

echo "--- passwordless sudo for $USER (needed by the service to restart itself) ---"
if ! sudo -n true 2>/dev/null; then
    echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/010_$USER-nopasswd >/dev/null
    sudo chmod 440 /etc/sudoers.d/010_$USER-nopasswd
fi

echo "--- packages ---"
sudo apt-get update -q
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    adb android-sdk-platform-tools-common git gcc pkg-config meson ninja-build \
    libsdl3-dev libavcodec-dev libavdevice-dev libavformat-dev libavutil-dev \
    libswresample-dev libusb-1.0-0-dev wget libdrm-tests python3-gpiozero python3-lgpio

echo "--- scrcpy $SCRCPY_VERSION (not packaged for Raspbian, build from source, ~2 min on Zero 2 W) ---"
if ! scrcpy --version 2>/dev/null | grep -q "${SCRCPY_VERSION#v}"; then
    rm -rf ~/scrcpy-src
    git clone -q --depth 1 --branch "$SCRCPY_VERSION" https://github.com/Genymobile/scrcpy.git ~/scrcpy-src
    cd ~/scrcpy-src
    wget -q -O scrcpy-server "https://github.com/Genymobile/scrcpy/releases/download/$SCRCPY_VERSION/scrcpy-server-$SCRCPY_VERSION"
    meson setup x --buildtype=release --strip -Db_lto=true -Dprebuilt_server="$PWD/scrcpy-server"
    ninja -C x -j"$(nproc)"
    sudo ninja -C x install
    cd ~
fi
echo "scrcpy: $(scrcpy --version 2>&1 | head -1)"

echo "--- udev: any Android in ADB mode is accessible without root ---"
sudo install -m 644 "$HERE/zero/99-android-monitorshift.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo usermod -aG plugdev,video,input,render,tty "$USER"

echo "--- station scripts -> /home/$USER ---"
install -m 755 "$HERE/zero/stanice.sh" "$HERE/zero/stanice_lib.sh" "$HERE/zero/stanice_hlidac.sh" \
               "$HERE/zero/pripravit.sh" "$HERE/zero/vratit.sh" "$HERE/zero/spanek.sh" "$HERE/zero/tlacitko.py" ~/
sed "s|/home/pi|/home/$USER|g; s|User=pi|User=$USER|; s|Group=pi|Group=$USER|" "$HERE/zero/tlacitko.service" | sudo tee /etc/systemd/system/tlacitko.service >/dev/null
sed "s|/home/pi|/home/$USER|g" "$HERE/zero/stanice.service" | sudo tee /etc/systemd/system/stanice.service >/dev/null
sudo sed -i "s|User=pi|User=$USER|; s|Group=pi|Group=$USER|" /etc/systemd/system/stanice.service
[ "$USER" != pi ] && sed -i "s|/home/pi|/home/$USER|g" ~/stanice.sh ~/stanice_lib.sh ~/pripravit.sh ~/vratit.sh ~/spanek.sh ~/tlacitko.py

echo "--- service: takes over tty1, starts at boot ---"
sudo systemctl daemon-reload
sudo systemctl disable getty@tty1.service 2>/dev/null
sudo systemctl enable stanice.service tlacitko.service
sudo systemctl restart tlacitko.service
sudo systemctl restart stanice.service
sleep 3
systemctl is-active stanice.service

cat <<EOF

=== done ===
Plug an Android phone with USB debugging enabled into the hub.
First time per phone: confirm "Allow USB debugging" on the phone (tick "Always allow").
Tip: copy ~/.android/adbkey and adbkey.pub from a PC the phones already trust
     into ~/.android/ on the Pi and no dialog will appear at all.
Logs: ~/stanice.log (Pi)   /data/local/tmp/stanice_hlidac.log (phone)
EOF
