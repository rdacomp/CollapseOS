#!/usr/bin/python

# Read specified number of bytes in specified blkdev ID and spit it to stdout.
# The proper blkdev has to be selected and placed already.

import argparse
import os
import sys
import time

# Some place where it's safe to write 0xff bytes.
MEMPTR = '9000'

def sendcmd(fd, cmd):
    # The serial link echoes back all typed characters and expects us to read
    # them. We have to send each char one at a time.
    print("Executing {}".format(cmd.decode()), file=sys.stderr)
    for c in cmd:
        os.write(fd, bytes([c]))
        os.read(fd, 1)
    os.write(fd, b'\n')
    os.read(fd, 2)  # sends back \r\n


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('device')
    parser.add_argument('bytecount')
    args = parser.parse_args()

    try:
        bytecount = int(args.bytecount, 16)
    except ValueError:
        print("bytecount has to be hexadecimal without prefix.")
        return 1
    fd = os.open(args.device, os.O_RDWR)
    sendcmd(fd, 'mptr {}'.format(MEMPTR).encode())
    os.read(fd, 9)
    while bytecount > 0:
        toread = min(bytecount, 0x100)
        sendcmd(fd, 'load {:x}'.format(toread & 0xff).encode())
        os.read(fd, 5)
        sendcmd(fd, 'peek {:x}'.format(toread & 0xff).encode())
        peek = b''
        while len(peek) < toread * 2:
            peek += os.read(fd, 1)
            time.sleep(0.0001)
        os.read(fd, 5)
        while peek:
            c = peek[:2]
            sys.stdout.buffer.write(bytes([int(c, 16)]))
            peek = peek[2:]
        bytecount -= toread
    os.close(fd)
    return 0

if __name__ == '__main__':
    sys.exit(main())

