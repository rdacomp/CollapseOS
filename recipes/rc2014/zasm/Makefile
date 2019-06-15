# source files required to build os.bin. We copy them in cfsin so that we can
# build the same kernel from within the RC2014.
KERNEL_SRCS = err.h acia.asm blockdev.asm blockdev_cmds.asm core.asm fs.asm \
	fs_cmds.asm mmap.asm parse.asm pgm.asm sdc.asm shell.asm stdio.asm

CFSTARGETS = $(addprefix cfsin/, zasm sdct at28w user.h $(KERNEL_SRCS))
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

cfsin/at28w: $(ZASMBIN)
	$(ZASM) $(APPS) $(KERNEL) user.h < $(APPS)/at28w/glue.asm > $@

cfsin/user.h: user.h
	cp $< $@
cfsin/err.h: $(KERNEL)/err.h
	cp $< $@
cfsin/%.asm: $(KERNEL)/%.asm
	cp $< $@

.PHONY: clean
clean:
	rm -f $(CFSTARGETS) sdcard.cfs os.bin
