TARGETS = shell/shell zasm/zasm runbin/runbin
KERNEL_HEADERS = shell/kernel.h zasm/kernel.h
USER_HEADERS = zasm/user.h
CFSPACK = ../cfspack/cfspack

.PHONY: all
all: $(TARGETS)

shell/kernel.h: shell/shell_.asm
zasm/kernel.h: zasm/glue.asm
$(KERNEL_HEADERS):
	scas -o - -I ../../parts/z80 $< | ./bin2c.sh KERNEL | tee $@ > /dev/null

zasm/user.h: zasm/user.asm
	scas -o - -I ../../apps $< | ./bin2c.sh USERSPACE | tee $@ > /dev/null

zasm/includes.cfs: ../../parts/z80 $(CFSPACK)
	cp -rf $< zasm/includes
	find zasm/includes -name *.md -delete
	find zasm/includes -type f -exec sed -i -e 's/;.*//g' {} \;
	$(CFSPACK) zasm/includes > $@
	rm -rf zasm/includes

zasm/includes.h: zasm/includes.cfs
	./bin2c.sh FSDEV < $< | tee $@ > /dev/null
	
shell/shell: shell/shell.c libz80/libz80.o shell/kernel.h $(CFSPACK)
zasm/zasm: zasm/zasm.c libz80/libz80.o zasm/kernel.h zasm/user.h zasm/includes.h
runbin/runbin: runbin/runbin.c libz80/libz80.o
$(TARGETS):
	cc $< libz80/libz80.o -o $@

libz80/libz80.o: libz80/z80.c
	make -C libz80/codegen opcodes
	gcc -Wall -ansi -g -c -o libz80/libz80.o libz80/z80.c

$(CFSPACK):
	make -C ../cfspack

.PHONY: clean
clean:
	rm -f $(TARGETS) $(KERNEL_HEADERS) $(USER_HEADERS) zasm/includes.*
