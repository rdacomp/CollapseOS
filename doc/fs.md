# Using the filesystem

The Collapse OS filesystem (CFS) is a very simple FS that aims at implementation
simplicity first. It is not efficient or featureful, but allows you to get
play around with the concept of files so that you can conveniently run programs
targeting named blocks of data with in storage.

The filesystem sits on a block device and there can only be one active
filesystem at once.

Files are represented by adjacent blocks of `0x100` bytes with `0x20` bytes of
metadata on the first block. That metadata tells the location of the next block
which allows for block iteration.

To create a file, you must allocate blocks to it and these blocks can't be
grown (you have to delete the file and re-allocate it). When allocating new
files, Collapse OS tries to reuse blocks from deleted files if it can.

Once "mounted" (turned on with `fson`), you can list files, allocate new files
with `fnew`, mark files as deleted with `fdel` and, more importantly, open files
with `fopn`.

Opened files are accessed a independent block devices. It's the glue code that
decides how many file handles we'll support and to which block device ID each
file handle will be assigned.

For example, you could have a system with three block devices, one for ACIA and
one for a SD card and one for a file handle. You would mount the filesystem on
block device `1` (the SD card), then open a file on handle `0` with `fopn 0
filename`. You would then do `bsel 2` to select your third block device which
is mapped to the file you've just opened.

## Trying it in the emulator

The shell emulator in `tools/emul/shell` is geared for filesystem usage. If you
look at `shell_.asm`, you'll see that there are 4 block devices: one for
console, one for fake storage (`fsdev`) and two file handles (we call them
`stdout` and `stdin`, but both are read/write in this context).

The fake device `fsdev` is hooked to the host system through the `cfspack`
utility. Then the emulated shell is started, it checks for the existence of a
`cfsin` directory and, if it exists, it packs its content into a CFS blob and
shoves it into its `fsdev` storage.

To, to try it out, do this:

    $ mkdir cfsin
    $ echo "Hello!" > cfsin/foo
    $ echo "Goodbye!" > cfsin/bar
    $ ./shell

The shell, upon startup, automatically calls `fson` targeting block device `1`,
so it's ready to use:

    > fls
    foo
    bar
    > mptr 9000
    9000
    > fopn 0 foo
    > bsel 2
    > load 5
    > peek 5
    656C6C6F21
    > fdel bar
    > fls
    foo
    >
