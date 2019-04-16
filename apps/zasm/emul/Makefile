zasm: zasm.c libz80/libz80.so wrapper.h zasm.h
	cc $< -l z80 -L./libz80 -Wl,-rpath ./libz80 -o $@

libz80/libz80.so: libz80/Makefile
	make -C libz80

wrapper.h: wrapper.asm
	scas -o - $< | ./bin2c.sh WRAPPER > $@

zasm.h: ../zasm.asm
	scas -o - $< | ./bin2c.sh ZASM > $@
