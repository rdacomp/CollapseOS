CFSPACK = ../cfspack/cfspack
TARGETS = shell/shell zasm/zasm runbin/runbin
KERNEL = ../../kernel
APPS = ../../apps
ZASMBIN = zasm/zasm
ZASMSH = ../zasm.sh

.PHONY: all
all: $(TARGETS)

shell/kernel.h: shell/shell_.asm $(ZASMBIN)
	$(ZASMSH) $(KERNEL) < $< | ./bin2c.sh KERNEL | tee $@ > /dev/null

zasm/kernel.h: zasm/kernel.bin
	./bin2c.sh KERNEL < $< | tee $@ > /dev/null

zasm/user.h: zasm/zasm.bin
	./bin2c.sh USERSPACE < $< | tee $@ > /dev/null

shell/shell: shell/shell.c libz80/libz80.o shell/kernel.h 
$(ZASMBIN): zasm/zasm.c libz80/libz80.o zasm/kernel.h zasm/user.h $(CFSPACK)
runbin/runbin: runbin/runbin.c libz80/libz80.o
$(TARGETS):
	$(CC) $< libz80/libz80.o -o $@

libz80/libz80.o: libz80/z80.c
	make -C libz80/codegen opcodes
	$(CC) -Wall -ansi -g -c -o libz80/libz80.o libz80/z80.c

$(CFSPACK):
	make -C ../cfspack

.PHONY: updatebootstrap
updatebootstrap: $(ZASMBIN) $(INCCFS)
	$(ZASMSH) $(KERNEL) < zasm/glue.asm > zasm/kernel.bin
	$(ZASMSH) $(KERNEL) $(APPS) user.h < $(APPS)/zasm/glue.asm > zasm/zasm.bin

# Sometimes, when developing zasm, stuff get messed up and it's hard to unmess
# because zasm's brake-up ends up in its bootstrap bins. Sure, we can revert
# from git, but if we're in the middle of some work, it's inconvenient. As long
# as we don't diverge from scas's syntax, it can come to the recue!
.PHONY: rescue
rescue:
	scas -o zasm/kernel.bin -I $(KERNEL) zasm/glue.asm
	scas -o zasm/zasm.bin -I $(APPS) -I $(KERNEL) $(APPS)/zasm/glue.asm

.PHONY: clean
clean:
	rm -f $(TARGETS) zasm/{kernel,user}.h shell/kernel.h zasm/includes.*
