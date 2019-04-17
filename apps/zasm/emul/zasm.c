#include <stdint.h>
#include <stdio.h>
#include "libz80/z80.h"
#include "kernel.h"
#include "zasm.h"

/* zasm is a "pure memory" application. It starts up being told memory location
 * to read and memory location to write.
 *
 * This program works be writing stdin in a specific location in memory, run
 * zasm in a special wrapper, wait until we receive the stop signal, then
 * spit the contents of the dest memory to stdout.
 */

// in sync with glue.asm
#define READFROM 0xa000
#define WRITETO 0xd000
#define ZASM_CODE_OFFSET 0x8000

static Z80Context cpu;
static uint8_t mem[0xffff];
static int running;
// Number of bytes written to WRITETO
// We receive that result from an OUT (C), A call. C contains LSB, A is MSB.
static uint16_t written;


static uint8_t io_read(int unused, uint16_t addr)
{
    return 0;
}

static void io_write(int unused, uint16_t addr, uint8_t val)
{
    written = ((addr & 0xff) << 8) + (val & 0xff);
    running = 0;
}

static uint8_t mem_read(int unused, uint16_t addr)
{
    return mem[addr];
}

static void mem_write(int unused, uint16_t addr, uint8_t val)
{
    mem[addr] = val;
}

int main()
{
    // initialize memory
    for (int i=0; i<sizeof(KERNEL); i++) {
        mem[i] = KERNEL[i];
    }
    for (int i=0; i<sizeof(ZASM); i++) {
        mem[i+ZASM_CODE_OFFSET] = ZASM[i];
    }
    int ptr = READFROM;
    int c = getchar();
    while (c != EOF) {
        mem[ptr] = c;
        ptr++;
        c = getchar();
    }
    // Run!
    running = 1;
    Z80RESET(&cpu);
    cpu.ioRead = io_read;
    cpu.ioWrite = io_write;
    cpu.memRead = mem_read;
    cpu.memWrite = mem_write;

    while (running) {
        Z80Execute(&cpu);
    }

    for (int i=0; i<written; i++) {
        putchar(mem[WRITETO+i]);
    }
    return 0;
}
