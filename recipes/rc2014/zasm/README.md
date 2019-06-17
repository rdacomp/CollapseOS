# Assembling binaries

For a system to be able to self-reproduce, it needs to assemble source z80
assembly to binary.

## Goals

Have a RC2014 assemble a Collapse OS kernel with its source living on a CFS on
a SD card.

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
    > fnew 1 dest
    > fopn 1 dest
    > zasm 1 2
    > dest
    Assembled from a RC2014
    >

That RC2014 is starting to feel powerful now, right?

## Test your hardware

Now that you have a fully functional filesystem that can load programs and run
them easily, you'll see that this recipe's CFS include a couple of programs
besides `zasm`. Among them, there's `sdct` that stress tests reading and
writing on the SD card and `memt` that stress tests RAM. You might be
interested in running them. Look at their description in `apps/`. All you need
to to do run them is to type their name.

## Assembling the kernel

Now let's go for something a little more fun! Jiu-jitsu? No, you're not going to
learn jiu-jitsu! You're going to assemble the kernel from within your RC2014!

The makefile doesn't prepare a CFS blob for this, let's learn to build that blob
yourself. First of all, we'll need to have what we already had in `sdcard.cfs`
because it has `zasm` and `user.h`. But we're going to add the contents of
the `/kernel/` directory to it.

    $ cp ../../../kernel/*.{h,asm} cfsin

You'll also need your glue file (at this time, the RC2014 can't assemble the
kernel of this very recipe, I'm not sure why. It can, however, assemble the
simpler kernel of the base RC2014 recipe. We'll use this one):

    $ cp ../glue.asm cfsin

You're now ready to re-make your CFS:

    $ rm sdcard.cfs && make

Now you can write this into your card and boot Collapse OS:

    Collapse OS
    > sdci
    > fson
    > fopn 0 glue.asm
    > fnew 10 dest
    > fopn 1 dest
    > zasm 1 2          # This takes a while. About 3 minutes.
    > sdcf              # success! sdcf flushes SD card buffers to the card.
