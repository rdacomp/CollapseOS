#include <stdint.h>
#include <stdio.h>
#include "libz80/z80.h"
#include "zasm-kernel.h"
#include "zasm-user.h"

/* zasm is a "pure memory" application. It starts up being told memory location
 * to read and memory location to write.
 *
 *
 * Memory layout:
 *
 * 0x0000 - 0x3fff: ROM code from zasm_glue.asm
 * 0x4000 - 0xffff: Userspace
 *
 * I/O Ports:
 *
 * 0 - stdin / stdout
 */

// in sync with zasm_glue.asm
#define USER_CODE 0x4000
#define STDIO_PORT 0x00

static Z80Context cpu;
static uint8_t mem[0xffff];

static uint8_t io_read(int unused, uint16_t addr)
{
    addr &= 0xff;
    if (addr == STDIO_PORT) {
        int c = getchar();
        if (c == EOF) {
            return 0;
        }
        return c;
    } else {
        fprintf(stderr, "Out of bounds I/O read: %d\n", addr);
        return 0;
    }
}

static void io_write(int unused, uint16_t addr, uint8_t val)
{
    addr &= 0xff;
    if (addr == STDIO_PORT) {
        putchar(val);
    } else {
        fprintf(stderr, "Out of bounds I/O write: %d / %d\n", addr, val);
    }
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
    for (int i=0; i<sizeof(USERSPACE); i++) {
        mem[i+USER_CODE] = USERSPACE[i];
    }
    Z80RESET(&cpu);
    cpu.ioRead = io_read;
    cpu.ioWrite = io_write;
    cpu.memRead = mem_read;
    cpu.memWrite = mem_write;

    while (!cpu.halted) {
        Z80Execute(&cpu);
    }
    fflush(stdout);
    return 0;
}

