PROGNAME = ps2ctl
AVRDUDEMCU ?= t45
AVRDUDEARGS ?= -c usbtiny -P usb 
TARGETS = $(PROGNAME).hex

# Rules

.PHONY: send all clean

all: $(TARGETS)
	@echo Done!

send: $(PROGNAME).hex
	avrdude $(AVRDUDEARGS) -p $(AVRDUDEMCU) -U flash:w:$<

$(PROGNAME).hex: $(PROGNAME).asm
$(TARGETS):
	avra -o $@ $<

clean:
	rm -f $(TARGETS) *.eep.hex *.obj

