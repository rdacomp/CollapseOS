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
    parser.add_argument('filename')
    args = parser.parse_args()

    st = os.stat(args.filename)
    if st.st_size > 0xff:
        print("File too big. 0xff bytes max")
        return 1
    fd = os.open(args.device, os.O_RDWR)
    sendcmd(fd, 'load {:x}'.format(st.st_size).encode())
    print("Loading...")
    with open(args.filename, 'rb') as fp:
        fcontents = fp.read()
        for c in fcontents:
            os.write(fd, bytes([c]))
            # Let's give the machine a bit of time to breathe. We ain't in a
            # hurry now, are we?
            time.sleep(0.0001)
    print("Loaded")
    os.read(fd, 5)
    print("Peeking back...")
    sendcmd(fd, 'peek {:x}'.format(st.st_size).encode())
    peek = b''
    while len(peek) < st.st_size * 2:
        peek += os.read(fd, 1)
        time.sleep(0.0001)
    os.close(fd)
    print("Got {}".format(peek.decode()))
    print("Comparing...")
    for i, c in enumerate(fcontents):
        hexfmt = '{:02X}'.format(c).encode()
        if hexfmt != peek[:2]:
            print("Mismatch at byte {}! {} != {}".format(i, peek[:2], hexfmt))
            return 1
        peek = peek[2:]
    print("All good!")
    return 0

if __name__ == '__main__':
    sys.exit(main())
