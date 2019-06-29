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

As of now, the interface is incomplete and can only be queried through the
shell's `iord`. I've set my device up for addr `8` (that is, I wired `A3`
through the inverter, the rest through diodes, and hooked this pudding to `OE`).

When doing `iord 8` in the shell, I get the scan code of the last key I pressed,
unless the 595 was "busy" with another code. For example, if I press `A`, my
next `iord 8` will yield `1C` (the "make" code for "A" in the PS/2 protocol).

Doing a second `iord 8` right after a first will yield `0`, indicating that the
device properly detect the first reading attempt and properly flushes the value
from the 595.

[avra]: https://github.com/hsoft/avra
