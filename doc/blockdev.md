# Using block devices

The `blockdev.asm` part manage what we call "block devices", an abstraction over
something that we can read a byte to, write a byte to and seek into (select at
which offset we will read/write to next).

A Collapse OS system can define up to `0xff` devices. Those definitions are made
in the glue code, so they are static.

Definition of block devices happen at include time. It would look like:

    [...]
    BLOCKDEV_COUNT .equ 1
    #include "blockdev.asm"
    ; List of devices
    .dw	aciaGetC, aciaPutC, 0
    [...]

That tells `blockdev` that we're going to set up one device, that its GetC and
PutC are the ones defined by `acia.asm` and that it has no Seek.

blockdev routines defined as zero are dummies (we don't actually call `0x0000`).

## Routine definitions

Parts that implement GetC, PutC and Seek do so in a loosely-coupled manner, but
they should try to adhere to the convention, that is:

**GetC**: Get a character at current position, advance the position by 1, then
          return the fetched character in register `A`. If no input is
          available, block until it is (in other words, we always get a valid
          character).

**PutC**: The opposite of GetC. Write the character in `A` at current position
          and advance. If it can't write, block until it can.

**Seek**: Set current position (word) to value in register `HL`.

## Shell usage

`blockdev.asm` supplies 2 shell commands that you can graft to your shell thus:

    [...]
    SHELL_EXTRA_CMD_COUNT	.equ	2
    #include "shell.asm"
    ; extra commands
    .dw	blkBselCmd, blkSeekCmd
    [...]

### bsel

`bsel` select the active block device. For now, this only affects `load`. It
receives one argument, the device index. `bsel 0` selects the first defined
device, `bsel 1`, the second, etc. Error `0x04` when argument is out of bounds.

### seek

`seek` receives one word argument and sets the pointer for the currently active
device to the specified address. Example: `seek 1234`.

The device position is device-specific: if you seek on a device, then switch
to another device and seek again, your previous position isn't lost. You will
still be on the same position when you come back.

### Example

Let's try an example: You glue yourself a Collapse OS with ACIA as its first
device and a mmap starting at `0xd000` as your second device. Here's what you
could do to copy memory around:

    > mptr d000
    D000
    > load 4 [device 0 is selected initially]
    [enter "abcd"]
    > peek 4
    61626364
    > mptr c000
    C000
    > peek 4
    [RAM garbage]
    > bsel 1
    > load 4
    [returns immediately]
    > peek 4
    61626364
    > seek 0002
    > load 2
    > peek 4
    63646364

Awesome, right?
