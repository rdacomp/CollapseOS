# Z80 Parts

Bits and pieces of code that you can assemble to build an OS for your machine.

These parts are made to be glued together in a single `main.asm` file you write
yourself.

As of now, the z80 assembler code is written to be assembled with [scas][scas],
but this is going to change in the future as a new hosted assembler is written.

## Defines

Each part can have its own constants, but some constant are made to be defined
externally. We already have some of those external definitions in platform
includes, but we can have more defines than this.

Each part has a "DEFINES" section listing the constant it expects to be defined.
Make sure that you have these constants defined before you include the file.

## Variable management

Each part can define variables. These variables are defined as addresses in
RAM. We know where RAM start from the `RAMSTART` constant in platform includes,
but because those parts are made to be glued together in no pre-defined order,
we need a system to align variables from different modules in RAM.

This is why each part that has variable expect a `<PARTNAME>_RAMSTART`
constant to be defined and, in turn, defines a `<PARTNAME>_RAMEND` constant to
carry to the following part.

Thus, code that glue parts together coould look like:

    MOD1_RAMSTART .equ RAMSTART
    #include "mod1.asm"
    MOD2_RAMSTART .equ MOD1_RAMEND
    #include "mod2.asm"

## Code style

The asm code used in these parts is heavily dependent on what scas offers. I
try to be as "low-tech" as possible because the implementation of the assembler
to be implemented for the z80 will likely be more limited. For example, I try
to avoid macros.

One exception, however, is for the routine hooks (`SHELL_GETC` for example). At
first, I wanted to assign a label to a const (`SHELL_GETC .equ aciaGetC` for
example), but it turns out that scas doesn't support this (but it could: label
addresses are known at compile time and thus can be consts (maybe at the cost
of an extra pass though)). I went for macros instead, but that doesn't mean
that the z80 assembler will need to support macros. It just need to support
labels-as-consts.

[scas]: https://github.com/KnightOS/scas
