# shell

The shell is a text interface giving you access to commands to control your
machine. It is not built to be user friendly, but to minimize binary space and
maximize code simplicity.

We expect the user of this shell to work with a copy of the user guide within
reach.

It is its design goal, however, to give you the levers you need to control your
machine fully.

## Commands and arguments

You invoke a command by typing its name, followed by a list of arguments. All
numerical arguments have to be typed in hexadecimal form, without prefix or
suffix. Lowercase is fine. Single digit is fine for byte (not word) arguments
smaller than `0x10`. Example calls:

    mptr 01ff
    peek 4
    poke 1f
    call 00 0123

All numbers printed by the shell are in hexadecimals form.

Whenever a command is malformed, the shell will print `ERR` with a code. This
table describes those codes:

| Code | Description               |
|------|---------------------------|
| `01` | Unknown command           |
| `02` | Badly formatted arguments |
| `03` | Out of bounds             |
| `04` | Unsupported command       |
| `05` | I/O error                 |

Applications have their own error codes as well. If you see an error code that
isn't in this list, it's an application-specific error code.

## mptr

The shell has a global memory pointer (let's call it `memptr`) that is used by
other commands. This pointer is 2 bytes long and starts at `0x0000`. To move
it, you use the mptr command with the new pointer position. The command
prints out the new `memptr` (just to confirm that it has run). Example:

    > mptr 42ff
    42FF

## peek

Read memory targeted by `memptr` and prints its contents in hexadecimal form.
This command takes one byte argument (optional, default to 1), the number of
bytes we want to read. Example:

    > mptr 0040
    0040
    > peek 2
    ED56

## poke

Puts the serial console in input mode and waits for a specific number of
characters to be typed (that number being specified by a byte argument). These
characters will be literally placed in memory, one after the other, starting at
`memptr`.

Example:

    > poke 5
    Hello
    > peek 5
    48656C6C6F

## call

Calls the routine at `memptr`, setting the `A` and `HL` registers to the value
specified by its optional arguments (default to 0).

Be aware that this results in a call, not a jump, so your routine needs to
return if you don't want to break your system.

The following example works in the case where you've made yourself a jump table
in your glue code a `jp printstr` at `0x0004`:

    > mptr a000
    A000
    > poke 6
    Hello\0 (you can send a null char through a terminal with CTRL+@)
    > mptr 0004
    0004
    > call 00 a000
    Hello> 
