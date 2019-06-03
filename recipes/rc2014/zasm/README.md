# Assembling binaries

For a system to be able to self-reproduce, it needs to assemble source z80
assembly to binary.

## Goals

Have a RC2014 assemble a Collapse OS kernel with its source living on a CFS on
a SD card.

**Work in progress: for now, we compile a simple hello.asm source file.**

## Gathering parts

* Same parts as the [SD card recipe](../sdcard).

## The zasm binary

To achieve our goal in this recipe, we'll need a zasm binary on the SD card.
This zasm binary needs to be compiled with the right jump offsets for the kernel
we build in this recipe. These offsets are in `user.h` and are closely in sync
with the configuration in `glue.asm`.

`user.h` is then included in `apps/zasm/glue.asm`.

The makefile in this recipe takes care of compiling zasm with the proper
`user.h` file and place it in `cfsin/zasm`

## The userland source

The code we're going to compile is `cfsin/hello.asm`. As you can see, we also
include `user.h` in this source code or else `ld hl, sAwesome` would load the
wrong offset.

Because of this, the Makefile takes care of copying `user.h` in our filesystem.

## Preparing the card and kernel

After running `make`, you'll end up with `sdcard.cfs` which you can load the
same way you did in the SD card recipe.

You will also have `os.bin`, which you can flash on your EEPROM the same way
you already did before.

## Running it

Compiling and running `hello.asm` is done very much like in
[the shell emulator](../../../doc/zasm.md):

    Collapse OS
    > sdci
    > fson
    > fopn 0 hello.asm
    > zasm 2 1
    > mptr 8600
    > bsel 1
    > seek 00 0000
    > load ff
    > call 00 0000
    Assembled from a RC2014

That RC2014 is starting to feel powerful now, right?
