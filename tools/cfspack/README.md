# cfspack

A tool/library to pack a directory into a CFS blob and unpack a CFS blob into
a directory.

## Usage

To pack a directory into a CFS blob, run:

    cfspack /path/to/directory

The blob is spit to stdout. If there are subdirectories, they will be prefixes
to the filenames under it.

The program errors out if a file name is too long (> 26 bytes) or too big
(> 0x10000 - 0x20 bytes).

To unpack a blob to a directory:

    cfsunpack /path/to/dest < blob

If destination exists, files are created alongside existing ones. If a file to
unpack already exists, it is overwritten.
