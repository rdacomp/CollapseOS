TARGETS = os.bin sdinit.bin
ZASM = ../../../tools/emul/zasm/zasm

.PHONY: all
all: $(TARGETS)
os.bin: glue.asm 
sdinit.bin: sdinit.asm
$(TARGETS):
	$(ZASM) < $< > $@
