# Sega Master System

The Sega Master System was a popular gaming console running on z80. It has a
simple, solid design and, most interestingly of all, its even more popular
successor, the Megadrive (Genesis) had a z80 system for compatibility!

This makes this platform *very* scavenge-friendly and worth working on.

[SMS Power][smspower] is an awesome technical resource to develop for this
platform and this is where most of my information comes from.

This platform is tight on RAM. It has 8k of it. However, if you have extra RAM,
you can put it on your cartridge.

## Status

I'm experimenting. Collapse OS doesn't run on the SMS yet. There are two main
challenges to solve: interfacing a keyboard through its I/O system (should be
feasible. from what I read in the I/O specs, it's very well done and adaptable)
and interface with its VDP (Video Display Processor).

After that, I'll look into using the explansion slot so that I can reuse the
RC2014 bus to, for example, access SD cards.

## Usage

The binary produced by the Makefile here has been tested on a Genesis +
[Everdrive MD][everdrive] (I haven't built myself a writable cartridge yet).

It is an adaptation of Maxim's (from SMS power) hello world. I converted it to
ZASM. It shows a letter in the range of "a" to "i" depending of which button on
controller A is pressed (only detects one button at once). All buttons of the
genesis controller are supported. Shows "i" when no button is pressed.

I've also added the mandatory "TMR SEGA" header at the end of the binary.

[smspower]: http://www.smspower.org
[everdrive]: https://krikzz.com
