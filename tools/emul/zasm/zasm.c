#include <stdint.h>
#include <stdio.h>
#include "../libz80/z80.h"
#include "kernel-bin.h"
#include "zasm-bin.h"

/* zasm reads from a specified blkdev, assemble the file and writes the result
 * in another specified blkdev. In our emulator layer, we use stdin and stdout
 * as those specified blkdevs.
 *
 * This executable takes one argument: the path to a .cfs file to use for
 * includes.
 *
 * Because the input blkdev needs support for Seek, we buffer it in the emulator
 * layer.
 *
 * Memory layout:
 *
 * 0x0000 - 0x3fff: ROM code from zasm_glue.asm
 * 0x4000 - 0x47ff: RAM for kernel and stack
 * 0x4800 - 0x57ff: Userspace code
 * 0x5800 - 0xffff: Userspace RAM
 *
 * I/O Ports:
 *
 * 0 - stdin / stdout
 * 1 - When written to, rewind stdin buffer to the beginning.
 */

// in sync with zasm_glue.asm
#define USER_CODE 0x4800
#define STDIO_PORT 0x00
#define STDIN_SEEK_PORT 0x01
#define FS_DATA_PORT 0x02
#define FS_SEEK_PORT 0x03
#define STDERR_PORT 0x04

// Other consts
#define STDIN_BUFSIZE 0x8000
// When defined, we dump memory instead of dumping expected stdout
//#define MEMDUMP
//#define DEBUG

static Z80Context cpu;
static uint8_t mem[0x10000];
// STDIN buffer, allows us to seek and tell
static uint8_t inpt[STDIN_BUFSIZE];
static int inpt_size;
static int inpt_ptr;
static uint8_t middle_of_seek_tell = 0;

static uint8_t fsdev[0x40000] = {0};
static uint32_t fsdev_size = 0;
static uint32_t fsdev_ptr = 0;
static uint8_t fsdev_seek_tell_cnt = 0;

static uint8_t io_read(int unused, uint16_t addr)
{
    addr &= 0xff;
    if (addr == STDIO_PORT) {
        if (inpt_ptr < inpt_size) {
            return inpt[inpt_ptr++];
        } else {
            return 0;
        }
    } else if (addr == STDIN_SEEK_PORT) {
        if (middle_of_seek_tell) {
            middle_of_seek_tell = 0;
            return inpt_ptr & 0xff;
        } else {
#ifdef DEBUG
            fprintf(stderr, "tell %d\n", inpt_ptr);
#endif
            middle_of_seek_tell = 1;
            return inpt_ptr >> 8;
        }
    } else if (addr == FS_DATA_PORT) {
        if (fsdev_ptr < fsdev_size) {
            return fsdev[fsdev_ptr++];
        } else {
            return 0;
        }
    } else if (addr == FS_SEEK_PORT) {
        if (fsdev_seek_tell_cnt != 0) {
            return fsdev_seek_tell_cnt;
        } else if (fsdev_ptr >= fsdev_size) {
            return 1;
        } else {
            return 0;
        }
    } else {
        fprintf(stderr, "Out of bounds I/O read: %d\n", addr);
        return 0;
    }
}

static void io_write(int unused, uint16_t addr, uint8_t val)
{
    addr &= 0xff;
    if (addr == STDIO_PORT) {
// When mem-dumping, we don't output regular stuff.
#ifndef MEMDUMP
        putchar(val);
#endif
    } else if (addr == STDIN_SEEK_PORT) {
        if (middle_of_seek_tell) {
            inpt_ptr |= val;
            middle_of_seek_tell = 0;
#ifdef DEBUG
            fprintf(stderr, "seek %d\n", inpt_ptr);
#endif
        } else {
            inpt_ptr = (val << 8) & 0xff00;
            middle_of_seek_tell = 1;
        }
    } else if (addr == FS_DATA_PORT) {
        if (fsdev_ptr < fsdev_size) {
            fsdev[fsdev_ptr++] = val;
        }
    } else if (addr == FS_SEEK_PORT) {
        if (fsdev_seek_tell_cnt == 0) {
            fsdev_ptr = val << 16;
            fsdev_seek_tell_cnt = 1;
        } else if (fsdev_seek_tell_cnt == 1) {
            fsdev_ptr |= val << 8;
            fsdev_seek_tell_cnt = 2;
        } else {
            fsdev_ptr |= val;
            fsdev_seek_tell_cnt = 0;
#ifdef DEBUG
            fprintf(stderr, "FS seek %d\n", fsdev_ptr);
#endif
        }
    } else if (addr == STDERR_PORT) {
        fputc(val, stderr);
    } else {
        fprintf(stderr, "Out of bounds I/O write: %d / %d (0x%x)\n", addr, val, val);
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

int main(int argc, char *argv[])
{
    if (argc > 2) {
        fprintf(stderr, "Too many args\n");
        return 1;
    }
    // initialize memory
    for (int i=0; i<sizeof(KERNEL); i++) {
        mem[i] = KERNEL[i];
    }
    for (int i=0; i<sizeof(USERSPACE); i++) {
        mem[i+USER_CODE] = USERSPACE[i];
    }
    fsdev_size = 0;
    if (argc == 2) {
        FILE *fp = fopen(argv[1], "r");
        if (fp == NULL) {
            fprintf(stderr, "Can't open file %s\n", argv[1]);
            return 1;
        }
        int c = fgetc(fp);
        while (c != EOF) {
            fsdev[fsdev_size] = c;
            fsdev_size++;
            c = fgetc(fp);
        }
        fclose(fp);
    }
    // read stdin in buffer
    inpt_size = 0;
    inpt_ptr = 0;
    int c = getchar();
    while (c != EOF) {
        inpt[inpt_ptr] = c & 0xff;
        inpt_ptr++;
        if (inpt_ptr == STDIN_BUFSIZE) {
            break;
        }
        c = getchar();
    }
    inpt_size = inpt_ptr;
    inpt_ptr = 0;
    Z80RESET(&cpu);
    cpu.ioRead = io_read;
    cpu.ioWrite = io_write;
    cpu.memRead = mem_read;
    cpu.memWrite = mem_write;

    while (!cpu.halted) {
        Z80Execute(&cpu);
    }
#ifdef MEMDUMP
    for (int i=0; i<0x10000; i++) {
        putchar(mem[i]);
    }
#endif
    fflush(stdout);
    int res = cpu.R1.br.A;
    if (res != 0) {
        int lineno = cpu.R1.wr.HL;
        int inclineno = cpu.R1.wr.DE;
        if (inclineno) {
            fprintf(
                stderr,
                "Error %d on line %d, include line %d\n",
                res,
                lineno,
                inclineno);
        } else {
            fprintf(stderr, "Error %d on line %d\n", res, lineno);
        }
    }
    return res;
}

