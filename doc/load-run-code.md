# Load code in RAM and run it

Collapse OS likely runs from ROM code. If you need to fiddle with your machine
more deeply, you will want to send arbitrary code to it and run it. You can do
so with the shell's `load` and `call` commands.

For example, let's say that you want to run this simple code that you have
sitting on your "modern" machine and want to execute on your running Collapse OS
machine:

    ld a, (0xa100)
    inc a
    ld (0xa100), a
    ret

(we must always return at the end of code that we call with `call`). This will
increase a number at memory address `0xa100`. First, compile it:

    zasm < tosend.asm > tosend.bin

Now, we'll send that code to address `0xa000`:

    > mptr a000
    A000
    > load 8 (resulting binary is 8 bytes long)

Now, at this point, it's a bit delicate. To pipe your binary to your serial
connection, you have to close `screen` with CTRL+A then `:quit` to free your
tty device. Then, you can run:

    cat tosend.bin > /dev/ttyUSB0 (or whatever is your device)

You can then re-open your connection with screen. You'll have a blank screen,
but if the number of characters sent corresponds to what you gave `load`, then
Collapse OS will be waiting for a new command. Go ahead, verify that the
transfer was successful with:

    peek 8
    3A00A13C3200A1C9

Good! Now, we can try to run it. Before we run it, let's peek at the value at
`0xa100` (being RAM, it's random):

    > mptr a100
    A100
    > peek
    61

So, we'll expect this to become `62` after we run the code. Let's go:

    > mptr a000
    A000
    > call 00 0000
    > mptr a100
    A100
    > peek
    62

Success!

## The upload.py tool

The serial connection is not always 100% reliable and a bad byte can slip in
when you push your code and that's not fun when you try to debug your code (is
this bad behavior caused by my logic or by a bad serial upload?).

To this end, there is a `upload.py` file in `tools/` that takes care of loading
the file and verify the contents. So, instead of doing `load 8` followed by
your `cat` above, you would have done:

    ./upload.py /dev/ttyUSB0 tosend.bin

This emits `load` and `peek` commands and fail appropriately if the `peek`
doesn't match sent contents. Very handy.

## Labels in RAM code

If your code contains any label, make sure that you add a `.org` directive at
the beginning of your code with the address you're planning on uploading your
code to. Otherwise, those labels are going to point to wrong addresses.

## Calling ROM code

The ROM you run Collapse OS on already has quite a bit of code in it, some of
it could be useful to programs you run from RAM.

If you know exactly where a routine lives in the ROM, you can `call` the address
directly, no problem. However, getting this information is tedious work and is
likely to change whenever you change the kernel code.

A good approach is to define yourself a jump table that you put in your glue
code. A good place for this is in the `0x03` to `0x37` range, which is empty
anyways (unless you set yourself up with some `rst` jumps) and is needed to
have a proper interrupt hook at `0x38`. For example, your glue code could look
like (important fact: `jp <addr>` uses 3 bytes):

    jp init
    ; JUMP TABLE
    jp printstr
    jp aciaPutC

    .fill 0x38-$
    jp aciaInt
    
    init:
    [...]

It then becomes easy to build yourself a predictable and stable jump header,
something you could call `jumptable.inc`:

    .equ    JUMP_PRINTSTR 0x03
    .equ    JUMP_ACIAPUTC 0x06

You can then include that file in your "user" code, like this:

    #include "jumptable.inc"
    .org 0xa000
    ld hl, label
    call JUMP_PRINTSTR
    ret

    label: .db "Hello World!", 0

If you load that code at `0xa000` and call it, it will print "Hello World!" by
using the `printstr` routine from `core.asm`.
