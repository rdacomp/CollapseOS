# RC2014

The [RC2014][rc2014] is a nice and minimal z80 system that has the advantage
of being available in an assembly kit. Assembling it yourself involves quite a
bit of soldering due to the bus system. However, one very nice upside of that
bus system is that each component is isolated and simple.

The machine used in this recipe is the "Classic" RC2014 with an 8k ROM module
, 32k of RAM, a 7.3728Mhz clock and a serial I/O.

The ROM module being supplied in the assembly kit is an EPROM, not EEPROM, so
you can't install Collapse OS on it. You'll have to supply your own.

There are many options around to boot arbitrary sources. What was used in this
recipe was a AT28C64B EEPROM module. I chose it because it's compatible with
the 8k ROM module which is very convenient. If you do the same, however, don't
forget to set the A14 jumper to high because what is the A14 pin on the AT27
ROM module is the WE pin on the AT28! Setting the jumper high will keep is
disabled.

## Related recipes

This recipe is for installing a minimal Collapse OS system on the RC2014. There
are other recipes related to the RC2014:

* [Writing to a AT28 from Collapse OS](eeprom/README.md)
* [Accessing a MicroSD card](sdcard/README.md)
* [Assembling binaries](zasm/README.md)
* [Interfacing a PS/2 keyboard](ps2/README.md)

## Goal

Have the shell running and accessible through the Serial I/O.

## Pre-collapse

You'll need specialized tools to write data to the AT28 EEPROM. There seems to
be many devices around made to write in flash and EEPROM modules, but being in
a "understand everything" mindset, I [built my own][romwrite]. This is the
device I use in this recipe.

### Gathering parts

* [zasm][zasm]
* [romwrite][romwrite] and its specified dependencies
* [GNU screen][screen]
* A FTDI-to-TTL cable to connect to the Serial I/O module of the RC2014

### Write glue.asm

[This is what your glue code would look like.](glue.asm)

The `platform.inc` include is there to load all platform-specific constants
(such as `RAMSTART` and `RAMEND`).

Then come the reset vectors. If course, we have our first jump to our main init
routine, and then we have a jump to the interrupt handler defined in `acia.asm`.

We need to plug this one in so that we can receive characters from the ACIA.

Then comes the usual `di` to aoid interrupts during init, and stack setup.

We set interrupt mode to 1 because that's what `acia.asm` is written around.

Then, we init ACIA, shell, enable interrupt and give control of the main loop
to `shell.asm`.

What comes below is actual code include from parts we want to include in our
OS. As you can see, we need to tell each module where to put their variables.
See `parts/README.md` for details.

You can also see from the `SHELL_GETC` and `SHELL_PUTC` macros that the shell
is decoupled from the ACIA and can get its IO from anything. See
`parts/README.md` for details.

### Build the image

We only have the shell to build, so it's rather straightforward:

    zasm < glue.asm > rom.bin

### Write to the ROM

Plug your romwrite atmega328 to your computer and identify the tty bound to it.
In my case (arduino uno), it's `/dev/ttyACM0`. Then:

    screen /dev/ttyACM0 9600
    CTRL-A + ":quit"
    cat rom.bin | pv -L 10 > /dev/ttyACM0

See romwrite's README for details about these commands.

### Running

Put the AT28 in the ROM module, don't forget to set the A14 jumper high, then
power the thing up. Connect the FTDI-to-TTL cable to the Serial I/O module and
identify the tty bound to it (in my case, `/dev/ttyUSB0`). Then:

    screen /dev/ttyUSB0 115200

Press the reset button on the RC2014 and you should see the Collapse OS prompt!

## Post-collapse

TODO

[rc2014]: https://rc2014.co.uk
[romwrite]: https://github.com/hsoft/romwrite
[zasm]: ../../tools/emul
[screen]: https://www.gnu.org/software/screen/
