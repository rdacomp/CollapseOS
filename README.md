# Collapse OS

*Bootstrap post-collapse technology*

Collapse OS is a z80 kernel and a collection of programs, tools and
documentation that allows you to assemble an OS that, when completed, will be
able to:

1. Run on an extremely minimal and improvised architecture.
2. Communicate through a improvised serial interface linked to some kind of
   improvised terminal.
3. Edit text files.
4. Compile assembler source files for a wide range of MCUs and CPUs.
5. Write files to a wide range of flash ICs and MCUs.
6. Access data storage from improvised systems.
7. Replicate itself.

Additionally, the goal of this project is to be as self-contained as possible.
With a copy of this project, a capable and creative person should be able to
manage to build and install Collapse OS without external resources (i.e.
internet) on a machine of her design, built from scavenged parts with low-tech
tools.

## Status

The project unfinished but is progressing well! Highlights:

* Self replicates: Can assemble itself from within itself, given enough RAM and
  storage.
* Has a shell that can poke memory, I/O, call arbitrary code from memory.
* Can "upload" code from serial link into memory and execute it.
* Can manage multiple "block devices".
* Can read and write to SD cards.
* A z80 assembler, written in z80 that is self-assembling and can assemble the
  whole project.
* Compact:
  * Kernel: 3K binary, 1800 SLOC.
  * ZASM: 4K binary, 2300 SLOC, 16K RAM usage to assemble kernel or itself.
* Extremely flexible: Kernel parts are written as loosely knit modules that
  are bound through glue code. This makes the kernel adaptable to many unforseen
  situations.
* From a GNU environment, can be built with minimal tooling: only
  [libz80][libz80], make and a C compiler are needed.

## More information

Go to [Collapse OS' website](https://collapseos.org) for more information on the
project.

[libz80]: https://github.com/ggambetta/libz80
