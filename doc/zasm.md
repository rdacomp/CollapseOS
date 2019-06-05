# Assembling z80 source from the shell

In its current state, Collapse OS has all you need to assemble z80 source
from within the shell. What you need is:

* A mounted filesystem with `zasm` on it.
* A block device to read from (can be a file from mounted CFS)
* A block device to write to (can theoretically be a file, but technical
  limitations temporary prevents us that. We'll use a mmap for now).

The emulated shell is already set up with all you need. If you want to run that
on a real machine, you'll have to make sure to provide these requirements.

The emulated shell has a `hello.asm` file in its mounted filesystem that is
ready to compile. It has two file handles 0 and 1, mapped to blk IDs 1 and 2.
We only use file handle 0 (blk ID 1) and then tell zasm to output to mmap which
is configured to start at `0xe00`

    Collapse OS
    > fopn 0 hello.asm      ; open file in handle 0
    > zasm 1 3              ; assemble opened file and spit result in mmap
    > bsel 3                ; select mmap
    > mptr e000             ; set memptr to mmap's beginning
    > peek 5
    210890CD3C              ; looking good
    > mptr 4200             ; hello.asm is configured to run from 0x4200
    > load ff               ; load compiled code from mmap
    > peek 5
    210890CD3C              ; looking good
    > call 00 0000
    Assembled from the shell
    >                       ; Awesome!
