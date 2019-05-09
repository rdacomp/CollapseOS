#include <stdint.h>
#include <stdio.h>
#include <termios.h>
#include "libz80/z80.h"
#include "shell-kernel.h"

/* Collapse OS vanilla shell
 *
 * Memory layout:
 *
 * 0x0000 - 0x3fff: ROM code from shell.asm
 * 0x4000 - 0x4fff: Kernel memory
 * 0x5000 - 0xffff: Userspace
 *
 * I/O Ports:
 *
 * 0 - stdin / stdout
 */

// in sync with shell.asm
#define RAMSTART 0x4000
#define STDIO_PORT 0x00
#define STDIN_ST_PORT 0x01

static Z80Context cpu;
static uint8_t mem[0xffff];
static int running;

static uint8_t io_read(int unused, uint16_t addr)
{
    addr &= 0xff;
    if (addr == STDIO_PORT) {
        uint8_t c = getchar();
        if (c == EOF) {
            running = 0;
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
        if (val == 0x04) { // CTRL+D
            running = 0;
        } else {
            putchar(val);
        }
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
    // Turn echo off: the shell takes care of its own echoing.
    struct termios termInfo;
    if (tcgetattr(0, &termInfo) == -1) {
        printf("Can't setup terminal.\n");
        return 1;
    }
    termInfo.c_lflag &= ~ECHO;
    termInfo.c_lflag &= ~ICANON;
    tcsetattr(0, TCSAFLUSH, &termInfo);


    // initialize memory
    for (int i=0; i<sizeof(SHELL_KERNEL); i++) {
        mem[i] = SHELL_KERNEL[i];
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

    printf("Done!\n");
    termInfo.c_lflag |= ECHO;
    termInfo.c_lflag |= ICANON;
    tcsetattr(0, TCSAFLUSH, &termInfo);
    return 0;
}
