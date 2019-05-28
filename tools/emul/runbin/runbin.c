#include <stdint.h>
#include <stdio.h>
#include "../libz80/z80.h"

/* runbin loads binary from stdin directly in memory address 0 then runs it
 * until it halts. The return code is the value of the register A at halt time.
 */

static Z80Context cpu;
static uint8_t mem[0x10000];

static uint8_t io_read(int unused, uint16_t addr)
{
    addr &= 0xff;
    fprintf(stderr, "Out of bounds I/O read: %d\n", addr);
    return 0;
}

static void io_write(int unused, uint16_t addr, uint8_t val)
{
    addr &= 0xff;
    fprintf(stderr, "Out of bounds I/O write: %d / %d\n", addr, val);
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
    // read stdin in mem
    int i = 0;
    int c = getchar();
    while (c != EOF) {
        mem[i] = c & 0xff;
        i++;
        c = getchar();
    }
    if (!i) {
        fprintf(stderr, "No input, aborting\n");
        return 1;
    }
    Z80RESET(&cpu);
    cpu.ioRead = io_read;
    cpu.ioWrite = io_write;
    cpu.memRead = mem_read;
    cpu.memWrite = mem_write;

    while (!cpu.halted) {
        Z80Execute(&cpu);
    }
    return cpu.R1.br.A;
}

