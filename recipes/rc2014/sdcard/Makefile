TARGETS = os.bin cfsin/helo
TOOLS = ../../../tools
ZASM = $(TOOLS)/zasm.sh
KERNEL = ../../../kernel
CFSPACK = $(TOOLS)/cfspack/cfspack

.PHONY: all
all: $(TARGETS) sdcard.cfs
os.bin: glue.asm 
cfsin/helo: helo.asm
$(TARGETS):
	$(ZASM) $(KERNEL) < $< > $@

$(CFSPACK):
	make -C $(TOOLS)/cfspack

sdcard.cfs: cfsin $(CFSPACK)
	$(CFSPACK) $< > $@
