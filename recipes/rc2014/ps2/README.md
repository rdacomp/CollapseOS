# Interfacing a PS/2 keyboard

Serial connection through ACIA is nice, but you are probably plugging a modern
computer on the other side of that ACIA, right? Let's go a step further away
from those machines and drive a PS/2 keyboard directly!

## Goal

Have a PS/2 keyboard drive the stdio input of the Collapse OS shell instead of
the ACIA.

**Status: work in progress**

## Gathering parts

* A RC2014 Classic that could install the base recipe
* A PS/2 keyboard. A USB keyboard + PS/2 adapter should work, but I haven't
  tried it yet.
* A PS/2 female connector. Not so readily available, at least not on digikey. I
  de-soldered mine from an old motherboard I had laying around.
* ATtiny85/45/25 (main MCU for the device)
* 74xx595 (shift register)
* 40106 inverter gates
* Diodes for `A*`, `IORQ`, `RO`.
* Proto board, RC2014 header pins, wires, IC sockets, etc.
* [AVRA][avra]

## Building the PS/2 interface

TODO. I have yet to draw presentable schematics. By reading `ps2ctl.asm`, you
might be able to guess how things are wired up.

It's rather straigtforward: the attiny reads serial data from PS/2 and then
sends it to the 595. The 595 is wired straight to D7:0 with its `OE` wired to
address selection + `IORQ` + `RO`

## Using the PS/2 interface

After having built and flashed the `glue.asm` supplied with this recipe, you end
up with a shell driven by the PS/2 keyboard (but it still outputs to ACIA).

You will see, by typing on the keyboard, that it kinda works, but in a very
basic and glitchy way. You will get double letters sometimes, and at some point,
communications are likely to become "corrupted" (you reliably get the wrong
letters). That's because parity checks, timeouts and reset procedures aren't
implemented yet.

But still, it kinda works!

[avra]: https://github.com/hsoft/avra
