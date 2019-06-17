#!/usr/bin/python

# Read specified number of bytes at specified memory address and dump it to
# stdout.

import argparse
import os
import sys
import time

def sendcmd(fd, cmd):
    # The serial link echoes back all typed characters and expects us to read
    # them. We have to send each char one at a time.
    for c in cmd:
        os.write(fd, bytes([c]))
        os.read(fd, 1)
    os.write(fd, b'\n')
    os.read(fd, 2)  # sends back \r\n


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('device')
    parser.add_argument('memptr')
    parser.add_argument('bytecount')
    args = parser.parse_args()

    try:
        memptr = int('0x' + args.memptr, 0)
    except ValueError:
        print("memptr are has to be hexadecimal without prefix.")
        return 1
    try:
        bytecount = int('0x' + args.bytecount, 0)
    except ValueError:
        print("bytecount are has to be hexadecimal without prefix.")
        return 1
    if memptr >= 0x10000:
        print("memptr out of range.")
        return 1
    if bytecount + memptr >= 0x10000:
        print("Bytecount too big.")
        return 1
    fd = os.open(args.device, os.O_RDWR)
    while bytecount > 0:
        sendcmd(fd, 'mptr {:04x}'.format(memptr).encode())
        os.read(fd, 9)
        toread = min(bytecount, 0xff)
        sendcmd(fd, 'peek {:x}'.format(toread).encode())
        peek = b''
        while len(peek) < toread * 2:
            peek += os.read(fd, 1)
            time.sleep(0.0001)
        os.read(fd, 5)
        while peek:
            c = peek[:2]
            sys.stdout.buffer.write(bytes([int(c, 16)]))
            peek = peek[2:]
        memptr += toread
        bytecount -= toread
    os.close(fd)
    return 0

if __name__ == '__main__':
    sys.exit(main())

