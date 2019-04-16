zasm: zasm.c libz80/libz80.so kernel.h zasm.h
	cc $< -l z80 -L./libz80 -Wl,-rpath ./libz80 -o $@

libz80/libz80.so: libz80/Makefile
	make -C libz80

kernel.h: glue.asm
	scas -o - -I ../../../parts $< | ./bin2c.sh KERNEL | tee $@ > /dev/null

zasm.h: ../zasm.asm
	scas -o - -I ./emul $< | ./bin2c.sh ZASM | tee $@ > /dev/null
