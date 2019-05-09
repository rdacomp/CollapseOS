.PHONY: all
all: shell

shell-kernel.h: shell_.asm
	scas -o - -I ../../parts/z80 $< | ./bin2c.sh SHELL_KERNEL | tee $@ > /dev/null

shell: shell.c libz80/libz80.o shell-kernel.h
	cc $< libz80/libz80.o -o $@

libz80/libz80.o: libz80/z80.c
	make -C libz80/codegen opcodes
	gcc -Wall -ansi -g -c -o libz80/libz80.o libz80/z80.c

.PHONY: clean
clean:
	rm shell shell-kernel.h
