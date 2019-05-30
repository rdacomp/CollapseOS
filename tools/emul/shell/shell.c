#include <stdint.h>
#include <stdio.h>
#include <termios.h>
#include "../libz80/z80.h"
#include "kernel.h"

/* Collapse OS shell with filesystem
 *
 * On startup, if "cfsin" directory exists, it packs it as a afke block device
 * and loads it in. Upon halting, unpcks the contents of that block device in
 * "cfsout" directory.
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
 * 1 - Filesystem blockdev data read/write. Reading and writing to it advances
 *     the pointer.
 * 2 - Filesystem blockdev seek / tell. Low byte
 * 3 - Filesystem blockdev seek / tell. High byte
 */

//#define DEBUG

// in sync with shell.asm
#define RAMSTART 0x4000
#define STDIO_PORT 0x00
#define FS_DATA_PORT 0x01
#define FS_SEEKL_PORT 0x02
#define FS_SEEKH_PORT 0x03
#define FS_SEEKE_PORT 0x04

static Z80Context cpu;
static uint8_t mem[0xffff] = {0};
static uint8_t fsdev[0x20000] = {0};
static uint32_t fsdev_size = 0;
static uint32_t fsdev_ptr = 0;
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
    } else if (addr == FS_DATA_PORT) {
        if (fsdev_ptr < fsdev_size) {
#ifdef DEBUG
            fprintf(stderr, "Reading FSDEV at offset %d\n", fsdev_ptr);
#endif
            return fsdev[fsdev_ptr++];
        } else {
            fprintf(stderr, "Out of bounds FSDEV read at %d\n", fsdev_ptr);
            return 0;
        }
    } else if (addr == FS_SEEKL_PORT) {
        return fsdev_ptr & 0xff;
    } else if (addr == FS_SEEKH_PORT) {
        return (fsdev_ptr >> 8) & 0xff;
    } else if (addr == FS_SEEKE_PORT) {
        return (fsdev_ptr >> 16) & 0xff;
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
    } else if (addr == FS_DATA_PORT) {
        if (fsdev_ptr < fsdev_size) {
            fsdev[fsdev_ptr++] = val;
        } else {
            fprintf(stderr, "Out of bounds FSDEV write at %d\n", fsdev_ptr);
        }
    } else if (addr == FS_SEEKL_PORT) {
        fsdev_ptr = (fsdev_ptr & 0xffff00) | val;
    } else if (addr == FS_SEEKH_PORT) {
        fsdev_ptr = (fsdev_ptr & 0xff00ff) | (val << 8);
    } else if (addr == FS_SEEKE_PORT) {
        fsdev_ptr = (fsdev_ptr & 0x00ffff) | (val << 16);
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
    if (addr < RAMSTART) {
        fprintf(stderr, "Writing to ROM (%d)!\n", addr);
    }
    mem[addr] = val;
}

int main()
{
    // Setup fs blockdev
    FILE *fp = popen("../cfspack/cfspack cfsin", "r");
    if (fp != NULL) {
        printf("Initializing filesystem\n");
        int i = 0;
        int c = fgetc(fp);
        while (c != EOF) {
            fsdev[i] = c & 0xff;
            i++;
            c = fgetc(fp);
        }
        fsdev_size = i;
        pclose(fp);
    } else {
        printf("Can't initialize filesystem. Leaving blank.\n");
    }

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
    for (int i=0; i<sizeof(KERNEL); i++) {
        mem[i] = KERNEL[i];
    }
    // Run!
    running = 1;
    Z80RESET(&cpu);
    cpu.ioRead = io_read;
    cpu.ioWrite = io_write;
    cpu.memRead = mem_read;
    cpu.memWrite = mem_write;

    while (running && !cpu.halted) {
        Z80Execute(&cpu);
    }

    printf("Done!\n");
    termInfo.c_lflag |= ECHO;
    termInfo.c_lflag |= ICANON;
    tcsetattr(0, TCSAFLUSH, &termInfo);
    return 0;
}
