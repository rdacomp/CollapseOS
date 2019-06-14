# Writing to a AT28 from Collapse OS

## Goal

Write in an AT28 EEPROM from within Collapse OS so that you can have it update
itself.

## Gathering parts

* A RC2014 Classic that could install the base recipe
* An extra AT28C64B
* 1x 40106 inverter gates
* Proto board, RC2014 header pins, wires, IC sockets, etc.

## Building the EEPROM holder

The AT28 is SRAM compatible so you could use a RAM module for it. However,
there is only one RAM module with the Classic version of the RC2014 and we
need it to run Collapse OS.

You could probably use the 64K RAM module for this purpose, but I don't have one
and I haven't tried it. For this recipe, I built my own module which is the same
as the regular ROM module but with `WR` wired and geared for address range
`0x2000-0x3fff`.

If you're tempted by the idea of hacking your existing RC2014 ROM module by
wiring `WR` and write directly to the range `0x0000-0x1fff` while running it,
be aware that it's not that easy. I was also tempted by this idea, tried it,
but on bootup, it seems that some random `WR` triggers happen and it corrupts
the EEPROM contents. Theoretically, we could go around that my putting the AT28
in write protection mode, but I preferred building my own module.

I don't think you need a schematic. It's really simple.

## Building the kernel

For this recipe to work, we need a block device for the `at28w` program to read
from. The easiest way to go around would be to use a SD card, but maybe you
haven't built a SPI relay yet and it's quite a challenge to do so.

Therefore, for this recipe, we'll have `at28w` read from a memory map and we'll
upload contents to write to memory through our serial link.

`at28w` is designed to be ran as a "user application", but in this case, because
we run from a kernel without a filesystem and that `pgm` can't run without it,
we'll integrate `at28w` directly in our kernel and expose it as an extra shell
command (renaming it to `a28w` to fit the 4 chars limit).

For all this to work, you'll need [glue code that looks like this](glue.asm).
Running `make` in this directory will produce a `os.bin` with that glue code
that you can install in the same way you did with the basic RC2014 recipe.

If your range is different than `0x2000-0x3fff`, you'll have to modify
`AT28W_MEMSTART` before you build.

## Writing contents to the AT28

The memory map is configured to start at `0xd000`. The first step is to upload
contents at that address as documented in ["Load code in RAM and run it"][load].

You have to know the size of the contents you've loaded because you'll pass it
as at argument to `a28w`. You can run:

    Collapse OS
    > bsel 0
    > seek 00 0000
    > a28w <size-of-contents>

It takes a little while to write. About 1 second per 0x100 bytes (soon, I'll
implement page writing which should make it much faster).

If the program doesn't report an error, you're all good! The program takes care
of verifying each byte, so everything should be in place. You can verify
yourself by `peek`-ing around the `0x2000-0x3fff` range.

Note that to write a single byte to the AT28 eeprom, you don't need a special
program. You can, while you're in the `0x2000-0x3fff` range, run `poke 1` and
send an arbitrary char. It will work. The problem is with writing multiple
bytes: you have to wait until the eeprom is finished writing before writing to
a new address, something a regular `poke` doesn't do but `at28w` does.

[load]: ../../../doc/load-run-code.md

