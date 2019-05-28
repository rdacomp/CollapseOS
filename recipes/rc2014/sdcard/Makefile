TARGETS = os.bin
TOOLS = ../../../tools
ZASM = $(TOOLS)/emul/zasm/zasm
CFSPACK = $(TOOLS)/cfspack/cfspack

.PHONY: all
all: $(TARGETS) sdcard.cfs
os.bin: glue.asm 
$(TARGETS):
	$(ZASM) < $< > $@

$(CFSPACK):
	make -C $(TOOLS)/cfspack

sdcard.cfs: cfsin $(CFSPACK)
	$(CFSPACK) $< > $@
