#include <stdint.h>
#include "libz80/z80.h"
#include "wrapper.h"
#include "zasm.h"

/* zasm is a "pure memory" application. It starts up being told memory location
 * to read and memory location to write.
 *
 * This program works be writing stdin in a specific location in memory, run
 * zasm in a special wrapper, wait until we receive the stop signal, then
 * spit the contents of the dest memory to stdout.
 */
static Z80Context cpu;
static uint8_t mem[0xffff];
static int running;


static uint8_t io_read(int unused, uint16_t addr)
{
    return 0;
}

static void io_write(int unused, uint16_t addr, uint8_t val)
{
    // zasm doesn't do any IO. If we receive any IO, it means that we're done
    // because the wrapper told us through an "out"
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
    int wrapperlen = sizeof(WRAPPER);
    for (int i=0; i<wrapperlen; i++) {
        mem[i] = WRAPPER[i];
    }
    int zasm = sizeof(ZASM);
    for (int i=0; i<zasm; i++) {
        mem[i+wrapperlen] = ZASM[i];
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
    printf("and... %d!\n", mem[0x100]);
    return 0;
}
