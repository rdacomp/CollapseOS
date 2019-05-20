# emul

This folder contains a couple of tools running under the [libz80][libz80]
emulator.

## Build

First, make sure that the `libz80` git submodule is checked out. If not, run
`git submodule init && git submodule update`.

After that, you can run `make` and it builds all tools.

## shell

Running `shell/shell` runs the shell in an emulated machine. The goal of this
machine is not to simulate real hardware, but rather to serve as a development
platform. What we do here is we emulate the z80 part, the 64K memory space and
then hook some fake I/Os to stdin, stdout and a small storage device that is
suitable for Collapse OS's filesystem to run on.

Through that, it becomes easier to develop userspace applications for Collapse
OS.

We don't try to emulate real hardware to ease the development of device drivers
because so far, I don't see the advantage of emulation versus running code on
the real thing.

## zasm

`zasm/zasm` is `apps/zasm` wrapped in an emulator. It is quite central to the
Collapse OS project because it's used to assemble everything, including itself!

The program takes no parameter. It reads source code from stdin and spits
binary in stdout. It supports includes and had both `apps/` and `kernel` folder
packed into a CFS that was statically included in the executable at compile
time.

The file `zasm/zasm.bin` is a compiled binary for `apps/zasm/glue.asm` and
`zasm/kernel.bin` is a compiled binary for `tools/emul/zasm/glue.asm`. It is
used to bootstrap the assembling process so that no assembler other than zasm
is required to build Collapse OS.

This binary is fed to libz80 to produce the `zasm/zasm` "modern" binary and
once you have that, you can recreate `zasm/zasm.bin` and `zasm/kernel.bin`.

This is why it's included as a binary in the repo, but yes, it's redundant with
the source code.

Those binaries can be updated with the `make updatebootstrap` command. If they
are up-to date and that zasm isn't broken, this command should output the same
binary as before.

## runbin

This is a very simple tool that reads binary z80 code from stdin, loads it in
memory starting at address 0 and then run the code until it halts. The exit
code of the program is the value of `A` when the program halts.

This is used for unit tests.
