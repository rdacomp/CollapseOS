TARGETS = shell/shell zasm/zasm runbin/runbin
CFSPACK = ../cfspack/cfspack
KERNEL = ../../kernel
APPS = ../../apps
ZASMBIN = zasm/zasm

.PHONY: all
all: $(TARGETS)

shell/kernel.h: shell/shell_.asm
	scas -o - -I $(KERNEL) $< | ./bin2c.sh KERNEL | tee $@ > /dev/null

zasm/kernel.h: zasm/kernel.bin
	./bin2c.sh KERNEL < $< | tee $@ > /dev/null

zasm/user.h: zasm/zasm.bin
	./bin2c.sh USERSPACE < $< | tee $@ > /dev/null

zasm/includes.cfs: $(CFSPACK)
	rm -rf zasm/includes
	cp -r $(KERNEL) zasm/includes
	cp -r $(APPS)/zasm zasm/includes/zasm
	find zasm/includes -name *.md -o -name *.example -o -name glue.asm -delete
	find zasm/includes -type f -exec sed -i -e 's/;.*//g' {} \;
	cp user.h zasm/includes
	$(CFSPACK) zasm/includes > $@
	rm -rf zasm/includes

zasm/includes.h: zasm/includes.cfs
	./bin2c.sh FSDEV < $< | tee $@ > /dev/null
	
shell/shell: shell/shell.c libz80/libz80.o shell/kernel.h $(CFSPACK)
$(ZASMBIN): zasm/zasm.c libz80/libz80.o zasm/kernel.h zasm/user.h zasm/includes.h
runbin/runbin: runbin/runbin.c libz80/libz80.o
$(TARGETS):
	cc $< libz80/libz80.o -o $@

libz80/libz80.o: libz80/z80.c
	make -C libz80/codegen opcodes
	gcc -Wall -ansi -g -c -o libz80/libz80.o libz80/z80.c

$(CFSPACK):
	make -C ../cfspack

.PHONY: updatebootstrap
updatebootstrap: $(ZASMBIN)
	$(ZASMBIN) < zasm/glue.asm > zasm/kernel.bin
	$(ZASMBIN) < $(APPS)/zasm/glue.asm > zasm/zasm.bin

.PHONY: clean
clean:
	rm -f $(TARGETS) zasm/{kernel,user}.h shell/kernel.h zasm/includes.*
