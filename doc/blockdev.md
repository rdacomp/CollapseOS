# Using block devices

The `blockdev.asm` part manage what we call "block devices", an abstraction over
something that we can read a byte to, write a byte to, optionally at arbitrary
offsets.

A Collapse OS system can define up to `0xff` devices. Those definitions are made
in the glue code, so they are static.

Definition of block devices happen at include time. It would look like:

    [...]
    BLOCKDEV_COUNT .equ 1
    #include "blockdev.asm"
    ; List of devices
    .dw	aciaGetC, aciaPutC
    [...]

That tells `blockdev` that we're going to set up one device, that its GetC and
PutC are the ones defined by `acia.asm`.

If your block device is read-only or write-only, use dummy routines. `unsetZ`
is a good choice since it will return with the `Z` flag unset, indicating an
error (dummy methods aren't supposed to be called).

Each defined block device, in addition to its routine definition, holds a
seek pointer. This seek pointer is used in shell commands described below.

## Routine definitions

Parts that implement GetC and PutC do so in a loosely-coupled manner, but
they should try to adhere to the convention, that is:

**GetC**: Get the character at position specified by `HL`. If it supports 32-bit
          addressing, `DE` contains the high-order bytes. Return the result in
          `A`. If there's an error (for example, address out of range), unset
          `Z`. This routine is not expected to block. We expect the result to be
          immediate.

**PutC**: The opposite of GetC. Write the character in `A` at specified
          position. `Z` unset on error.
          
## Shell usage

`blockdev.asm` supplies 4 shell commands that you can graft to your shell thus:

    [...]
    SHELL_EXTRA_CMD_COUNT	.equ	4
    #include "shell.asm"
    ; extra commands
    .dw	blkBselCmd, blkSeekCmd, blkLoadCmd, blkSaveCmd
    [...]

### bsel

`bsel` select the active block device. This specify a target for `load` and
`save`. Some applications also use the active blockdev. It receives one
argument, the device index. `bsel 0` selects the first defined device, `bsel 1`,
the second, etc. Error `0x04` when argument is out of bounds.

### seek

`seek` receives one word argument and sets the pointer for the currently active
device to the specified address. Example: `seek 1234`.

The device position is device-specific: if you seek on a device, then switch
to another device and seek again, your previous position isn't lost. You will
still be on the same position when you come back.

### load

`load` works a bit like `poke` except that it reads its data from the currently
active blockdev at its current position. If it hits the end of the blockdev
before it could load its specified number of bytes, it stops. It only raises an
error if it couldn't load any byte.

It moves the device's position to the byte after the last loaded byte.

### save

`save` is the opposite of `load`. It writes the specified number of bytes from
memory to the active blockdev at its current position.

It moves the device's position to the byte after the last written byte.

### Example

Let's try an example: You glue yourself a Collapse OS with ACIA as its first
device and a mmap starting at `0xd000` as your second device. Here's what you
could do to copy memory around:

    > mptr d000
    D000
    > poke 4
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
    > seek 00 0002
    > load 2
    > peek 4
    63646364

Awesome, right?
