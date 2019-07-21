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
