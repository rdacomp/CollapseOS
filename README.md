# Collapse OS

*Bootstrap post-collapse technology*

Collapse OS is a z80 kernel and a collection of programs, tools and
documentation that allows you to assemble an OS that, when completed, will be
able to:

1. Run on minimal and improvised machines.
2. Interface through improvised means (serial, keyboard, display).
3. Edit text files.
4. Compile assembler source files for a wide range of MCUs and CPUs.
5. Read and write from a wide range of storage devices.
6. Replicate itself.

Additionally, the goal of this project is to be as self-contained as possible.
With a copy of this project, a capable and creative person should be able to
manage to build and install Collapse OS without external resources (i.e.
internet) on a machine of her design, built from scavenged parts with low-tech
tools.

## Organisation of this repository

* `kernel`: Pieces of code to be assembled by the user into a kernel.
* `apps`: Pieces of code to be assembled into "userspace" application.
* `recipes`: collection of recipes that assemble parts together on a specific
             machine.
* `doc`: User guide for when you've successfully installed Collapse OS.
* `tools`: Tools for working with Collapse OS from "modern" environments. Mostly
           development tools, but also contains emulated zasm, which is
           necessary to build Collapse OS from a non-Collapse OS machine.

Each folder has a README with more details.

## Status

The project unfinished but is progressing well! See [Collapse OS' website][web]
for more information.

[libz80]: https://github.com/ggambetta/libz80
[web]: https://collapseos.org
