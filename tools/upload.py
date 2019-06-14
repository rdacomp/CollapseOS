#!/usr/bin/python

# Push specified file (max 0xff bytes) to specified device and verify that
# the contents is correct by sending a "peek" command afterwards and check
# the output. Errors out if the contents isn't the same. The parameter
# passed to the "peek" command is the length of the uploaded file.

import argparse
import os
import sys
import time

def sendcmd(fd, cmd):
    # The serial link echoes back all typed characters and expects us to read
    # them. We have to send each char one at a time.
    print("Executing {}".format(cmd.decode()))
    for c in cmd:
        os.write(fd, bytes([c]))
        os.read(fd, 1)
    os.write(fd, b'\n')
    os.read(fd, 2)  # sends back \r\n


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('device')
    parser.add_argument('memptr')
    parser.add_argument('filename')
    args = parser.parse_args()

    try:
        memptr = int('0x' + args.memptr, 0)
    except ValueError:
        print("memptr are has to be hexadecimal without prefix.")
        return 1
    if memptr >= 0x10000:
        print("memptr out of range.")
        return 1
    maxsize = 0x10000 - memptr
    st = os.stat(args.filename)
    if st.st_size > maxsize:
        print("File too big. 0x{:04x} bytes max".format(maxsize))
        return 1
    fd = os.open(args.device, os.O_RDWR)
    with open(args.filename, 'rb') as fp:
        while True:
            fcontents = fp.read(0xff)
            if not fcontents:
                break
            print("Seeking...")
            sendcmd(fd, 'mptr {:04x}'.format(memptr).encode())
            os.read(fd, 9)
            sendcmd(fd, 'poke {:x}'.format(len(fcontents)).encode())
            print("Poking...")
            for c in fcontents:
                os.write(fd, bytes([c]))
                # Let's give the machine a bit of time to breathe. We ain't in a
                # hurry now, are we?
                time.sleep(0.0001)
            print("Poked")
            os.read(fd, 5)
            print("Peeking back...")
            sendcmd(fd, 'peek {:x}'.format(len(fcontents)).encode())
            peek = b''
            while len(peek) < len(fcontents) * 2:
                peek += os.read(fd, 1)
                time.sleep(0.0001)
            os.read(fd, 5)
            print("Got {}".format(peek.decode()))
            print("Comparing...")
            for i, c in enumerate(fcontents):
                hexfmt = '{:02X}'.format(c).encode()
                if hexfmt != peek[:2]:
                    print("Mismatch at byte {}! {} != {}".format(i, peek[:2], hexfmt))
                    return 1
                peek = peek[2:]
            print("All good!")
            memptr += len(fcontents)
    print("Done!")
    os.close(fd)
    return 0

if __name__ == '__main__':
    sys.exit(main())
