PROGNAME = ps2ctl
AVRDUDEMCU ?= t45
AVRDUDEARGS ?= -c usbtiny -P usb 
TARGETS = $(PROGNAME).hex os.bin
ZASM = ../../../tools/zasm.sh
KERNEL = ../../../kernel

# Rules

.PHONY: send all clean

all: $(TARGETS)
	@echo Done!

send: $(PROGNAME).hex
	avrdude $(AVRDUDEARGS) -p $(AVRDUDEMCU) -U flash:w:$<

$(PROGNAME).hex: $(PROGNAME).asm
	avra -o $@ $<

os.bin: glue.asm
	$(ZASM) $(KERNEL) < $< > $@

clean:
	rm -f $(TARGETS) *.eep.hex *.obj os.bin
