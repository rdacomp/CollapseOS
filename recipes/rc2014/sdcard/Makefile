TARGETS = os.bin sdinit.bin
PARTS = ../../../parts/z80

.PHONY: all
all: $(TARGETS)
os.bin: glue.asm 
sdinit.bin: sdinit.asm
$(TARGETS):
	scas -o $@ -L map -I $(PARTS) $<
