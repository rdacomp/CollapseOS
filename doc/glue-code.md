# Writing the glue code

Collapse OS is not an OS, it's a meta OS. It supplies parts that you're expected
to glue together in a "glue code" asm file. Here is what a minimal glue code
for a shell on a Classic [RC2014][rc2014] with an ACIA link would look like:


    ; The RAM module is selected on A15, so it has the range 0x8000-0xffff
    RAMSTART	.equ	0x8000
    RAMEND		.equ	0xffff
    ACIA_CTL	.equ	0x80	; Control and status. RS off.
    ACIA_IO		.equ	0x81	; Transmit. RS on.

        jr init

    ; interrupt hook
    .fill	0x38-$
        jp aciaInt

    init:
        di
        ; setup stack
        ld hl, RAMEND
        ld sp, hl
        im 1
        call aciaInit
        call shellInit
        ei
        jp	shellLoop

    #include "core.asm"
    ACIA_RAMSTART	.equ	RAMSTART
    #include "acia.asm"
    SHELL_RAMSTART	.equ	ACIA_RAMEND
    .define SHELL_GETC	call aciaGetC
    .define SHELL_PUTC	call aciaPutC
    .define SHELL_IO_GETC	call aciaGetC
    SHELL_EXTRA_CMD_COUNT .equ 0
    #include "shell.asm"

Once this is written, building it is easy:

    scas -o collapseos.bin -I /path/to/parts glue.asm

## Platform constants

The upper part of the code contains platform-related constants, information
related to the platform you're targeting. You might want to put it in an
include file if you're writing multiple glue code that targets the same machine.

In all cases, `RAMSTART` are necessary. `RAMSTART` is the offset at which
writable memory begins. This is where the different parts store their
variables.

`RAMEND` is the offset where writable memory stop. This is generally
where we put the stack, but as you can see, setting up the stack is the
responsibility of the glue code, so you can set it up however you wish.

`ACIA_*` are specific to the `acia` part. Details about them are in `acia.asm`.
If you want to manage ACIA, you need your platform to define these ports.

## Header code

Then comes the header code (code at `0x0000`), a task that also is in the glue
code's turf. `jr init` means that we run our `init` routine on boot.

`jp aciaInt` at `0x38` is needed by the `acia` part. Collapse OS doesn't dictate
a particular interrupt scheme, but some parts might. In the case of `acia`, we
require to be set in interrupt mode 1.

## Includes

This is the most important part of the glue code and it dictates what will be
included in your OS. Each part is different and has a comment header explaining
how it works, but there are a couple of mechanisms that are common to all.

### Defines

Parts can define internal constants, but also often document a "Defines" part.
These are constant that are expected to be set before you include the file.

See comment in each part for details.

### RAM management

Many parts require variables. They need to know where in RAM to store these
variables. Because parts can be mixed and matched arbitrarily, we can't use
fixed memory addresses.

This is why each part that needs variable define a `<PARTNAME>_RAMSTART`
constant that must be defined before we include the part.

Symmetrically, each part define a `<PARTNAME>_RAMEND` to indicate where its
last variable ends.

This way, we can easily and efficiently chain up the RAM of every included part.

### Tables grafting

A mechanism that is common to some parts is "table grafting". If a part works
on a list of things that need to be defined by the glue code, it will place a
label at the very end of its source file. This way, it becomes easy for the
glue code to "graft" entries to the table. This approach, although simple and
effective, only works for one table per part. But it's often enough.

For example, to define extra commands in the shell:

    [...]
    SHELL_EXTRA_CMD_COUNT .equ 2
    #include "shell.asm"
    .dw myCmd1, myCmd2
    [...]

### Initialization

Then, finally, comes the `init` code. This can be pretty much anything really
and this much depends on the part you select. But if you want a shell, you will
usually end it with `shellLoop`, which never returns.

[rc2014]: https://rc2014.co.uk/
