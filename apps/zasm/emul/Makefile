zasm: zasm.c libz80/libz80.so kernel.h zasm.h
	cc $< -l z80 -L./libz80 -Wl,-rpath ./libz80 -o $@

libz80/libz80.so: libz80/Makefile
	make -C libz80

kernel.h: glue.asm
	scas -o - $< | ./bin2c.sh KERNEL > $@

zasm.h: ../zasm.asm
	scas -o - -I ./emul $< | ./bin2c.sh ZASM > $@
