# z80 assembler

This is probably the most critical part of the Collapse OS project because it
ensures its self-reproduction.

## Running on a "modern" machine

To be able to develop zasm efficiently, [libz80][libz80] is used to run zasm
on a modern machine. The code lives in `emul` and ran be built with `make`,
provided that you have a copy libz80 living in `emul/libz80`.

The resulting `zasm` binary takes asm code in stdin and spits binary in stdout.

## Literals

There are decimal, hexadecimal and binary literals. A "straight" number is
parsed as a decimal. Hexadecimal literals must be prefixed with `0x` (`0xf4`).
Binary must be prefixed with `0b` (`0b01100110`).

Decimals and hexadecimal are "flexible". Whether they're written in a byte or
a word, you don't need to prefix them with zeroes. Watch out for overflow,
however.

Binary literals are also "flexible" (`0b110` is fine), but can't go over a byte.

There is also the char literal (`'X'`), that is, two qutes with a character in
the middle. The value of that character is interpreted as-is, without any
encoding involved. That is, whatever binary code is written in between those
two quotes, it's what is evaluated. Only a single byte at once can be evaluated
thus. There is no escaping. `'''` results in `0x27`. You can't express a newline
this way, it's going to mess with the parser.

Then comes our last literal, the string literal. It's a chain of characters
surrounded by double quotes. Example: `"foo"`. This literal can only be used
in the `.db` directive and is equivalent to each character being single-quoted
and separated by commas (`'f', 'o', 'o'`). No null char is inserted in the
resulting value (unlike what C does).

## Labels

Lines starting with a name followed `:` are labeled. When that happens, the
name of that label is associated with the binary offset of the following
instruction.

For example, a label placed at the beginning of the file is associated with
offset 0. If placed right after a first instruction that is 2 bytes wide, then
the label is going to be bound to 2.

Those labels can then be referenced wherever a constant is expected. They can
also be referenced where a relative reference is expected (`jr` and `djnz`).

Labels can be forward-referenced, that is, you can reference a label that is
defined later in the source file or in an included source file.

Labels starting with a dot (`.`) are local labels: they belong only to the
namespace of the current "global label" (any label that isn't local). Local
namespace is wiped whenever a global label is encountered.

Local labels allows reuse of common mnemonics and make the assembler use less
memory.

Global labels are all evaluated during the first pass, which makes possible to
forward-reference them. Local labels are evaluated during the second pass, but
we can still forward-reference them through a "first-pass-redux" hack.

Labels can be alone on their line, but can also be "inlined", that is, directly
followed by an instruction.

## Constants

The `.equ` directive declares a constant. That constant's argument is an
expression that is evaluated right at parse-time.

Constants are evaluated during the second pass, which means that they can
forward-reference labels.

However, they *cannot* forward-reference other constants.


## Expressions

Wherever a constant is expected, an expression can be written. An expression
is a bunch of literals or symbols assembled by operators. For now, only `+`, `-`
and `*` operators are supported. No parenthesis yet.

Expressions can't contain spaces.

## The Program Counter

The `$` is a special symbol that can be placed in any expression and evaluated
as the current output offset. That is, it's the value that a label would have if
it was placed there.

## The Last Value

Whenever a `.equ` directive is evaluated, its resulting value is saved in a
special "last value" register that can then be used in any expression. This
is very useful for variable definitions and for jump tables.

## Includes

The `.inc` directive is special. It takes a string literal as an argument and
opens, in the currently active filesystem, the file with the specified name.

It then proceeds to parse that file as if its content had been copy/pasted in
the includer file, that is: global labels are kept and can be referenced
elsewhere. Constants too. An exception is local labels: a local namespace always
ends at the end of an included file.

There an important limitation with includes: only one level of includes is
allowed. An included file cannot have an `.inc` directive.

## Directives

**.db**: Write bytes specified by the directive directly in the resulting
         binary. Each byte is separated by a comma. Example: `.db 0x42, foo`

**.dw**: Same as `.db`, but outputs words. Example: `.dw label1, label2`

**.equ**: Binds a symbol named after the first parameter to the value of the
          expression written as the second parameter. Example:
          `.equ foo 0x42+'A'`
          
          If the symbol specified has already been defined, no error occur and
          the first value defined stays intact. This allows for "user override"
          of programs.

**.fill**: Outputs the number of null bytes specified by its argument, an
           expression. Often used with `$` to fill our binary up to a certain
           offset. For example, if we want to place an instruction exactly at
           byte 0x38, we would precede it with `.fill 0x38-$`.

**.org**: Sets the Program Counter to the value of the argument, an expression.
          For example, a label being defined right after a `.org 0x400`, would
          have a value of `0x400`. Does not do any filling. You have to do that
          explicitly with `.fill`, if needed. Often used to assemble binaries
          designed to run at offsets other than zero (userland).

**.out**: Outputs the value of the expression supplied as an argument to
          `ZASM_DEBUG_PORT`. The value is always interpreted as a word, so
          there's always two `out` instruction executed per directive. High byte
          is sent before low byte. Useful or debugging, quickly figuring our
          RAM constants, etc. The value is only outputted during the second
          pass.

**.inc**: Takes a string literal as an argument. Open the file name specified
          in the argument in the currently active filesystem, parse that file
          and output its binary content as is the code has been in the includer
          file.

**.bin**: Takes a string literal as an argument. Open the file name specified
          in the argument in the currently active filesystem and outputs its
          contents directly.

[libz80]: https://github.com/ggambetta/libz80
