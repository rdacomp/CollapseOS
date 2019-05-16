TARGETS = shell zasm
KERNEL_HEADERS = shell-kernel.h zasm-kernel.h
USER_HEADERS = zasm-user.h
CFSPACK = ../cfspack/cfspack

.PHONY: all
all: $(TARGETS)

shell-kernel.h: shell_.asm
zasm-kernel.h: zasm_glue.asm
$(KERNEL_HEADERS):
	scas -o - -I ../../parts/z80 $< | ./bin2c.sh KERNEL | tee $@ > /dev/null

zasm-user.h: zasm_user.asm
	scas -o - -I ../../apps/zasm $< | ./bin2c.sh USERSPACE | tee $@ > /dev/null

zasm-includes.h: ../../parts/z80 $(CFSPACK)
	cp -rf $< zasm-includes
	rm zasm-includes/README.md
	$(CFSPACK) zasm-includes | ./bin2c.sh FSDEV | tee $@ > /dev/null
	rm -rf zasm-includes

shell: shell.c libz80/libz80.o shell-kernel.h $(CFSPACK)
zasm: zasm.c libz80/libz80.o zasm-kernel.h zasm-user.h zasm-includes.h
$(TARGETS):
	cc $< libz80/libz80.o -o $@

libz80/libz80.o: libz80/z80.c
	make -C libz80/codegen opcodes
	gcc -Wall -ansi -g -c -o libz80/libz80.o libz80/z80.c

$(CFSPACK):
	make -C ../cfspack

.PHONY: clean
clean:
	rm -f $(TARGETS) $(KERNEL_HEADERS) $(USER_HEADERS)
