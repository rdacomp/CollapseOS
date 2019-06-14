# Assembling z80 source from the shell

In its current state, Collapse OS has all you need to assemble z80 source
from within the shell. What you need is:

* A mounted filesystem with `zasm` on it.
* A block device to read from (can be a file from mounted CFS)
* A block device to write to (can also be a file).

The emulated shell is already set up with all you need. If you want to run that
on a real machine, you'll have to make sure to provide these requirements.

The emulated shell has a `hello.asm` file in its mounted filesystem that is
ready to compile. It has two file handles 0 and 1, mapped to blk IDs 1 and 2.
We will open our source file in handle 0 and our dest file in handle 1. Then,
with the power of the `pgm` module, we'll autoload our newly compiled file and
execute it!

    Collapse OS
    > fnew 1 dest           ; create destination file
    > fopn 0 hello.asm      ; open source file in handle 0
    > fopn 1 dest           ; open dest binary in handle 1
    > zasm 1 2              ; assemble source file into binary file
    > dest                  ; call newly compiled file
    Assembled from the shell
    >                       ; Awesome!
