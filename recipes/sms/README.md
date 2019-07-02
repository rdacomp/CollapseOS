# Sega Master System

The Sega Master System was a popular gaming console running on z80. It has a
simple, solid design and, most interestingly of all, its even more popular
successor, the Megadrive (Genesis) had a z80 system for compatibility!

This makes this platform *very* scavenge-friendly and worth working on.

[SMS Power][smspower] is an awesome technical resource to develop for this
platform and this is where most of my information comes from.

This platform is tight on RAM. It has 8k of it. However, if you have extra RAM,
you can put it on your cartridge.

## Gathering parts

* [zasm][zasm]
* A Sega Master System or a MegaDrive (Genesis). (I have only tested on a
  MegaDrive so far)
* A Megadrive D-pad controller.
* A way to get an arbitrary ROM to run on the SMS. Either through a writable
  ROM card or an [Everdrive][everdrive].

## Build the ROM

Running `make` will produce a `os.sms` ROM that can be put as is on a SD card
to the everdrive or flashed as is on a writable ROM cart. Then, just run the
thing!

## Usage

On boot, you will get a regular Collapse OS shell. See the rest of the
documentation for shell usage instructions.

The particularity here is that, unlike with the RC2014, we don't access Collapse
OS through a serial link. Our input is a D-Pad and our output is a TV. The
screen is 32x28 characters. A bit tight, but usable.

D-Pad is used as follow:

* There's always an active cursor. On boot, it shows "a".
* Up/Down increase/decrease the value of the cursor.
* Left/Right does the same, by increments of 5.
* A button is backspace.
* B button skips cursor to next "class" (number, lowcase, upcase, symbols).
* C button "enters" cursor character and advance the cursor by one.
* Start button is like pressing Return.

Of course, that's not a fun way to enter text, but using the D-Pad is the
easiest way to get started. I'm working on a PS/2 keyboard adapter for the SMS.

[smspower]: http://www.smspower.org
[everdrive]: https://krikzz.com
[zasm]: ../../tools/emul
