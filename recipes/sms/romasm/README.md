# zasm and ed from ROM

SMS' RAM is much tighter than in the RC2014, which makes the idea of loading
apps like zasm and ed in memory before using it a bit wasteful. In this recipe,
we'll include zasm and ed code directly in the kernel and expose them as shell
commands.

Moreover, we'll carve ourselves a little 1K memory map to put a filesystem in
there. This will give us a nice little system that can edit small source files
compile them and run them.

## Gathering parts

* A SMS that can run Collapse OS.
* A [PS/2 keyboard adapter](../kbd/README.md)

## Build

There's nothing special with building this recipe. Like the base recipe, run
`make` then copy `os.sms` to your destination medium.

If you look at the makefile, however, you'll see that we use a new trick here:
we embed "apps" binaries directly in our ROM so that we don't have to load them
in memory.

## Usage

Alright, here's what we'll do: we'll author a source file, assemble it and run
it, *all* on your SMS! Commands:

    Collapse OS
    > fnew 1 src
    > ed src
    : 1i
    .org 0xc200
    : 1a
    ld hl, sFoo
    : 2a
    call 0x3f
    : 3a
    xor a
    : 4a
    ret
    : 5a
    sFoo: .db "foo", 0
    : w
    > fnew 1 dest
    > fopn 0 src
    > fopn 1 dest
    > zasm 1 2
    First pass
    Second pass
    > dest
    foo>

Awesome right? Some precisions:

* Our glue code specifies a `USER_RAMSTART` of `0xc200`. This is where
  `dest` is loaded by the `pgm` shell hook.
* `0x3f` is the offset of `printstr` in the jump table of our glue code.
* `xor a` is for the command to report as successful to the shell.
