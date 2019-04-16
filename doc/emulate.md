# Running Collapse OS on an emulated RC2014

To give Collapse OS a whirl or to use emulation as a development tool, I
recommend using Alan Cox's [RC2014 emulator][rc2014-emul]. It runs Collapse OS
fine. One caveat, however, is that it requires a ROM image bigger than 8K, so
you have to pad the binary.

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

[rc2014-emul]: https://github.com/EtchedPixels/RC2014
