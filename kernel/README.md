# Kernel

Bits and pieces of code that you can assemble to build a kernel for your
machine.

These parts are made to be glued together in a single `glue.asm` file you write
yourself.

This code is designed to be assembled by Collapse OS' own [zasm][zasm].

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

Thus, code that glue parts together could look like:

    MOD1_RAMSTART .equ RAMSTART
    #include "mod1.asm"
    MOD2_RAMSTART .equ MOD1_RAMEND
    #include "mod2.asm"

## Stack management

Keeping the stack "balanced" is a big challenge when writing assembler code.
Those push and pop need to correspond, otherwise we end up with completely
broken code.

The usual "push/pop" at the beginning and end of a routine is rather easy to
manage, nothing special about them.

The problem is for the "inner" push and pop, which are often necessary in
routines handling more data at once. In those cases, we walk on eggshells.

A naive approach could be to indent the code between those push/pop, but indent
level would quickly become too big to fit in 80 chars.

I've tried ASCII art in some places, where comments next to push/pop have "|"
indicating the scope of the push/pop. It's nice, but it makes code complicated
to edit, especially when dense comments are involved. The pipes have to go
through them.

Of course, one could add descriptions next to each push/pop describing what is
being pushed, and I do it in some places, but it doesn't help much in easily
tracking down stack levels.

So, what I've started doing is to accompany each "non-routine" (at the
beginning and end of a routine) push/pop with "--> lvl X" and "<-- lvl X"
comments. Example:

    push    af  ; --> lvl 1
    inc     a
    push    af  ; --> lvl 2
    inc     a
    pop     af  ; <-- lvl 2
    pop     af  ; <-- lvl 1

I think that this should do the trick, so I'll do this consistently from now on.
[zasm]: ../apps/zasm/README.md
