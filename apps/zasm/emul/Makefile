zasm: zasm.c libz80/libz80.o kernel.h zasm.h
	cc $< libz80/libz80.o -o $@

libz80/libz80.o: libz80/z80.c
	make -C libz80/codegen opcodes
	gcc -Wall -ansi -g -c -o libz80/libz80.o libz80/z80.c

kernel.h: glue.asm
	scas -o - -I ../../../parts/z80 $< | ./bin2c.sh KERNEL | tee $@ > /dev/null

zasm.h: ../main.asm ../instr.asm ../tok.asm
	scas -o - -I.. $< | ./bin2c.sh ZASM | tee $@ > /dev/null
