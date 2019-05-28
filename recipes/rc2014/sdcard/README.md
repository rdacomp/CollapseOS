# Accessing a MicroSD card

**Status: work in progress.**

SD cards are great because they are accessible directly. No supporting IC is
necessary. The easiest way to access them is through the SPI protocol.

Due to the way IO works in z80, implementing SPI through it as a bit awkward:
You can't really keep pins high and low on an IO line. You need some kind of
intermediary between z80 IOs and SPI.

There are many ways to achieve this. This recipe explains how to build your own
hacked off SPI relay for the RC2014. It can then be used with `sdc.asm` to
drive a SD card.

## Goal

Read and write to a SD card from Collapse OS using a SPI relay of our own
design.

## Gathering parts

* A RC2014 with Collapse OS with these features:
  * shell
  * blockdev
  * sdc
* A MicroSD breakout board. I use Adafruit's.
* A proto board + header pins with 39 positions so we can make a RC2014 card.
* Diodes, resistors and stuff
* 40106 (Inverter gates)
* 4011 (NAND gates)
* 74xx139 (Decoder)
* 74xx161 (Binary counter)
* 74xx165 (Parallel input shift register)
* 74xx595 (Shift register)

## Building the SPI relay

The [schematic][schematic] supplied with this recipe works well with `sdc.asm`.
Of course, it's not the only possible design that works, but I think it's one
of the most straighforwards.

The basic idea with this relay is to have one shift register used as input,
loaded in parallel mode from the z80 bus and a shift register that takes the
serial input from `MISO` and has its output wired to the z80 bus.

These two shift registers are clocked by a binary counter that clocks exactly
8 times whenever a write operation on port `4` occurs. Those 8 clocks send
data we've just received in the `74xx165` into `MOSI` and get `MISO` into the
`74xx595`.

The `74xx139` then takes care of activating the right ICs on the right
combinations of `IORQ/WR/RD/Axx`.

The rest of the ICs is fluff around this all.

My first idea was to implement the relay with an AVR microcontroller to
minimize the number of ICs, but it's too slow. We have to be able to respond
within 300ns! Following that, it became necessary to add a 595 and a 165, but
if we're going to add that, why not go the extra mile and get rid of the
microcontroller?

To that end, I was heavily inspired by [this design][inspiration].

This board uses port `4` for SPI data, port `5` to pull `CS` low and port `6`
to pull it high. Port `7` is unused but monopolized by the card.

Little advice: If you make your own design, double check propagation delays!
Some NAND gates, such as the 4093, are too slow to properly respond within
a 300ns limit. For example, in my own prototype, I use a 4093 because that's
what I have in inventory. For the `CS` flip-flop, the propagation delay doesn't
matter. However, it *does* matter for the `SELECT` line, so I don't follow my
own schematic with regards to the `M1` and `A2` lines and use two inverters
instead.

## Building the kernel

To be able to work with your SPI relay and communicate with the card, you
should have [glue code that looks like this](glue.asm).

Initially, when you don't know if things work well yet, you should comment out
the block creation part.

## Reading from the SD card

The first thing we'll do is fill the SD card's first 12 bytes with "Hello
World!":

    echo "Hello World!" > /dev/sdX

Then, insert your SD card in your SPI relay and boot the RC2014.

Run the `sdci` command which will initialize the card. Then, run `bsel 1` to
select the second blockdev, which is configured to be the sd card.

Set your memory pointer to somewhere you can write to with `mptr 9000` and then
you're ready to load your contents with `load d` (load the 13 bytes that you
wrote to your sd card earlier. You can then `peek d` and see that your
"Hello World!\n" got loaded in memory!

[schematic]: spirelay/spirelay.pdf
[inspiration]: https://www.ecstaticlyrics.com/electronics/SPI/fast_z80_interface.html
