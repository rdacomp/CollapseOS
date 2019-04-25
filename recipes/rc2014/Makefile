TARGET = os.bin
PARTS = ../../parts/z80

.PHONY: all
all: $(TARGET)
$(TARGET): glue.asm
	scas -o $@ -L map -I $(PARTS) $<
