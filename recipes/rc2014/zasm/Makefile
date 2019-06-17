CFSTARGETS = $(addprefix cfsin/, zasm sdct memt at28w user.h)
BASE = ../../..
TOOLS = $(BASE)/tools
ZASM = $(TOOLS)/zasm.sh
KERNEL = $(BASE)/kernel
APPS = $(BASE)/apps
CFSPACK = $(TOOLS)/cfspack/cfspack

.PHONY: all
all: os.bin sdcard.cfs

os.bin: glue.asm
	$(ZASM) $(KERNEL) < $< > $@

$(CFSPACK):
	make -C $(TOOLS)/cfspack

sdcard.cfs: $(CFSTARGETS) $(CFSPACK)
	$(CFSPACK) cfsin > $@

cfsin/zasm: $(ZASMBIN)
	$(ZASM) $(KERNEL) $(APPS) user.h < $(APPS)/zasm/glue.asm > $@

cfsin/sdct: $(ZASMBIN)
	$(ZASM) $(APPS) user.h < $(APPS)/sdct/glue.asm > $@

cfsin/memt: $(ZASMBIN)
	$(ZASM) $(APPS) user.h < $(APPS)/memt/glue.asm > $@

cfsin/at28w: $(ZASMBIN)
	$(ZASM) $(APPS) $(KERNEL) user.h < $(APPS)/at28w/glue.asm > $@

cfsin/user.h: user.h
	cp $< $@

.PHONY: clean
clean:
	rm -f $(CFSTARGETS) sdcard.cfs os.bin
