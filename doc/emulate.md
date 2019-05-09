# Running Collapse OS on an emulator

The quickest way to give Collapse OS a whirl is to use `tools/emul` which is
built around [libz80][libz80]. Everything is set up, you just have to run
`make`.

To emulate something at a lower level, I recommend using Alan Cox's [RC2014
emulator][rc2014-emul]. It runs Collapse OS fine but you have to write the
glue code yourself. One caveat, also, is that it requires a ROM image bigger
than 8K, so you have to pad the binary.

A working Makefile for a project with a glue code being called `main.asm` could
look like:

    TARGET = os.bin
    PARTS = ~/collapseos/parts
    ROM = os.rom

    .PHONY: all
    all: $(ROM)
    $(TARGET): main.asm
            scas -o $@ -L map -I $(PARTS) $<

    $(ROM): $(TARGET)
            cp $< $@
            dd if=/dev/null of=$@ bs=1 count=1 seek=8192

    .PHONY: run
    run: $(ROM)
            ~/RC2014/rc2014 -r $(ROM)

`CTRL+\` stops the emulation.

[libz80]: https://github.com/ggambetta/libz80
[rc2014-emul]: https://github.com/EtchedPixels/RC2014
