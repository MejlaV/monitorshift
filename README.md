# MonitorShift

Turn any Android phone into a desktop touch computer — including one with a
**broken screen** and **no video output**.

A Raspberry Pi Zero 2 W mirrors the phone over USB onto a touch monitor and
sends the touches back. Plug the phone in, it works; unplug it, it goes back
to being a normal phone by itself. Rotate the monitor, the picture follows.
No root, nothing installed on the phone.

```
phone ──USB── Pi Zero 2 W ──HDMI──▶ touch monitor
                  └──USB hub── monitor touch, keyboard, mouse
```

Built because a Galaxy A52s had a half-dead display, no USB-C video out, and
a family that still wanted to use it. Tested on Samsung A52s (Android 14),
Raspberry Pi OS Lite trixie, Elo 1502L 15.6" touch monitor (1366×768).

## What makes it different from "scrcpy on a Pi"

| | plain scrcpy | MonitorShift |
|---|---|---|
| runs without X/desktop, straight on the console | manual | systemd service on tty1 |
| plug / unplug any phone, no typing | no | waits for a device, loops forever |
| phone settings for the big screen (resolution 1:1 with the monitor, brightness, never sleep) | manual | applied on plug-in, **reverted automatically 10 s after unplug** |
| revert survives the cable being pulled | – | a watchdog runs **inside the phone**, originals stored in the phone |
| monitor rotates 90° with the phone attached | manual | `--capture-orientation=@90` + phone's own g-sensor, picture always fills the screen |
| one ADB authorisation for the PC and the dock | – | share the ADB key |

## Hardware

- Raspberry Pi Zero 2 W (any Pi works; Zero 2 W is the cheapest that copes)
- micro-USB OTG adapter → **powered** USB hub (USB-C dock with PD passthrough works; it also powers the Pi through the data port)
- mini-HDMI → HDMI to the monitor
- touch monitor whose touch is a USB HID digitizer (Elo 1502L here; most are)
- the phone: USB debugging enabled, that's all
- a holder that fixes the phone to the monitor's VESA mount, so they rotate together — STLs in [`hardware/`](hardware/)

Power: the phone gets 500 mA from the hub as a USB device. With the panel dimmed it holds charge. A hub with a CDP (⚡) port charges faster.

## Install

On a fresh Raspberry Pi OS Lite (with Wi-Fi and SSH set up):

```bash
git clone https://github.com/rastamila/monitorshift.git
cd monitorshift
bash install.sh
```

Builds scrcpy 4.1 from source (Raspbian has no package; needs SDL3), installs
adb, udev rules, the scripts and the `stanice` service, and starts it. ~10 min
on a Zero 2 W, mostly package downloads.

Then plug in a phone. On the phone, confirm *Allow USB debugging* and tick
*Always allow*. To skip that dialog forever, copy `~/.android/adbkey` and
`adbkey.pub` from a computer the phones already trust into `~/.android/` on the Pi.

## How it works

**`stanice.sh`** (Pi, service) loops: wait for an authorised device → if the
phone is not yet in "station profile", save its current settings *into the
phone* and apply the profile → push and start the watchdog in the phone →
run scrcpy → when scrcpy exits (cable pulled), go back to waiting.

**Station profile** (all via `adb`, no root): logical display `768×1366`
(9:16, pixel-for-pixel with a 1366×768 monitor stood upright), density scaled to
match, screen never off, brightness minimum, auto-rotate **on**.

**`stanice_hlidac.sh`** (runs *in the phone*, started detached with
`setsid nohup`, so it survives the cable being pulled): polls `dumpsys usb`
every second; after 10 s without a USB host it restores the originals from
`settings global stanice_orig_*` and exits. A cable blip under 10 s changes
nothing. The Pi re-spawns it every minute while docked, in case Android kills it.

**Rotation.** The phone is bolted to the monitor, so their rotation is always
the same. scrcpy's `--capture-orientation=@90` (the `@` = *locked* to the
device's natural orientation) rotates the phone's *panel* by a constant 90°;
Android itself redraws the UI when the g-sensor turns. Upright monitor → 90°
turns the portrait panel into a full landscape frame. Monitor turned → Android
draws landscape UI on the portrait panel, the same 90° makes it upright. Frame
is always 1366×768, no black bars, touch mapped by scrcpy. No detection code.

## Files

```
install.sh                       one-shot installer for the Pi
zero/stanice.sh                  the service loop
zero/stanice_lib.sh              profile apply/revert, watchdog deploy (shared)
zero/stanice_hlidac.sh           watchdog that runs inside the phone
zero/stanice.service             systemd unit (tty1, restarts, groups)
zero/99-android-monitorshift.rules  udev: Android in ADB mode readable without root
zero/pripravit.sh  zero/vratit.sh   manual apply / revert, same library
hardware/                        STL for the VESA phone holder
```

Tuning lives at the top of `stanice_lib.sh` (`MON_W`, `MON_H`) and in the
`scrcpy` line of `stanice.sh` (`--max-size 1024 --max-fps 20 --video-bit-rate 2M`
is what a Zero 2 W sustains; a Pi 4 takes full resolution).

## Known limits — read before you build one

- **Lock screen on Samsung is black.** The pattern/PIN screen is flagged
  secure; scrcpy shows black but touches still work, so you can unlock blind or
  on the phone itself. The profile keeps the screen on, so the phone simply
  never locks while docked. It *will* ask after a reboot.
- **Revert needs the watchdog alive.** If the phone reboots *away* from the
  dock, the profile stays until it's docked and undocked again. Fixing that
  needs an app in the phone (Shizuku-style) — out of scope.
- **Tablets with landscape natural orientation** get the "never sleep /
  brightness" part of the profile but not the resolution; the holder and the
  `@90` trick assume a portrait-native device.
- **Zero 2 W decodes video on the CPU.** Expect ~100 ms latency and 20 fps at
  1024 px. Scrolling is fine, games are not. A Pi 4/5 removes the limit.
- `--turn-screen-off` looks tempting but Samsung then sends no frames on the
  lock screen. Brightness 1 instead.
- Do not force `SDL_RENDER_DRIVER=opengles2` on kmsdrm — black window.
  Software renderer is correct here.
- Raspbian trixie: `custom.toml` first-boot config was ignored on our image and
  the console wizard created a user without passwordless sudo. `install.sh`
  fixes the sudo part.

## Why not Chromecast / DeX / an app?

Tried Chromecast first. Picture works, touch does not, and it cannot be fixed
without root: Android maps an external USB touchscreen onto the *physical*
panel and never rotates it with the display (`InputDeviceOrientation: 0` in
`dumpsys input`). The 9:20 phone vs 16:9 monitor aspect ratios never line up on
both axes at once. scrcpy sidesteps all of it because touch is injected in
logical coordinates. DeX needs USB-C video out, which mid-range phones lack.

## License

MIT. Made by [rastamila](https://github.com/rastamila) with a lot of help from Claude.
