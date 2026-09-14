# Hardware

Phone holder for a VESA-mounted monitor, so the phone rotates together with
the screen (the `@90` trick in the README depends on it). Designed for
Galaxy A52s + Elo 1502L on a stand that pivots 90°.

- `MonitorFlipBody.stl` — body, screws to the VESA pattern; the Pi and the hub live in it too
- `MonitorFlipSlide.stl` — sliding clamp that holds the phone

## Printing (as tested)

- Prusa MK4, PrusaSlicer profile **0.25 mm**, **20 % infill**
- **PLA** (Plasty Mladeč) — a durability test; PETG would be the better choice
  for a part that carries a phone next to a warm Pi, use it if you have it
- **Supports: organic, only on the large flat face where the slide runs in**
- The body is long and printed without an enclosure, so it tends to warp.
  If it comes out slightly bowed, **shrink the slide by 0.5–1 mm in Z** to
  match — how much depends on how bowed the body is.

## Sleep button

Momentary push button between **GPIO3 (pin 5)** and **GND (pin 6)** on the Pi
header. No resistor, the internal pull-up is used. One press = sleep, next
press = wake (see README). GPIO3 also wakes a halted Pi, a free bonus.
