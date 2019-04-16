# z80 assembler

This is probably the most critical part of the Collapse OS project. If this app
can be brought to completion, it pretty much makes the project a success because
it ensures self-reproduction.

## Running on a "modern" machine

To be able to develop zasm efficiently, [libz80][libz80] is used to run zasm
on a modern machine. The code lives in `emul` and ran be built with `make`,
provided that you have a copy libz80 living in `emul/libz80`.

The resulting `zasm` binary takes asm code in stdin and spits binary in stdout.

[libz80]: https://github.com/ggambetta/libz80
