# Collapse OS

*Bootstrap post-collapse technology*

Collapse OS is a collection of programs, tools and documentation that allows
you to assemble an OS that can:

1. Run on an extremely minimal and improvised architecture.
2. Communicate through a improvised serial interface linked to some kind of
   improvised terminal.
3. Edit text files.
4. Compile assembler source files for a wide range of MCUs and CPUs.
5. Write files to a wide range of flash ICs and MCUs.
6. Access data storage from improvised systems.
7. Replicate itself.

Additionally, the goal of this project is to be as self-contained as possible.
With a copy of this project, a capable and creative person should be able to
manage to build and install Collapse OS without external resources (i.e.
internet) on a machine of her design, built from scavenged parts with low-tech
tools.

See the "Goals" section below for details.

## Why?

I expect our global supply chain to collapse before we reach 2030. With this
collapse, we won't be able to produce most of our electronics because it
depends on a very complex supply chain that we won't be able to achieve again
for decades (ever?).

The fast rate of progress we've seen since the advent of electronics happened
in very specific conditions that won't be there post-collapse, so we can't hope
to be able to bootstrap new electronic technology as fast we did without a good
"starter kit" to help us do so.

Electronics yield enormous power, a power that will give significant advantages
to communities that manage to continue mastering it. This will usher a new age
of *scavenger electronics*: parts can't be manufactured any more, but we have
billions of parts lying around. Those who can manage to create new designs from
those parts with low-tech tools will be very powerful.

Among these scavenged parts are microcontrollers, which are especially powerful
but need complex tools (often computers) to program them. Computers, after a
couple of decades, will break down beyond repair and we won't be able to
program microcontrollers any more.

To avoid this fate, we need to have a system that can be designed from
scavenged parts and program microcontrollers. We also need the generation of
engineers that will follow us to be able to *create* new designs instead of
inheriting a legacy of machines that they can't recreate and barely maintain.

This is where Collapse OS comes in.

## Goals

On face value, goals outlined in the introduction don't seem very ambitious,
that is, until we take the time to think about what kind of machines we are
likely to be able to build from scavenged parts without access to (functional)
modern technology.

By "minimal machine" I mean [Grant Searle's minimal z80 computer][searle].
This (admirably minimal and elegant) machine runs on 8k of ROM and 56k of RAM.
Anything bigger starts being much more complex because you need memory paging,
and if you need paging, then you need a kernel that helps you manage that,
etc.. Of course, I don't mean that these more complex computers can't be built
post-collapse, but that if we don't have a low-enough bar, we reduce the
likeliness for a given community to bootstrap itself using Collape OS.

Of course, with this kind of specs, a C compiler is out of the question. Even
full-fledged assembler is beginning to stretch the machine's ressources. The
assembler having to be written in assembler (to be self-replicating), we need
to design a watered-down version of our modern full-fledged assembler
languages.

But with assemblers, a text editor and a way to write data to flash, you have
enough to steadily improve your technological situation, build more
sophisticated machines from more sophisticated scavenged parts and, who knows,
in a couple of decades, build a new IC fab (or bring an old one back to life).

## Futile?

For now, this is nothing more than an idea, and a fragile one. This project is
only relevant if the collapse is of a specific magnitude. A weak-enough
collapse and it's useless (just a few fabs that close down, a few wars here and
there, hunger, disease, but people are nevertheless able to maintain current
technology levels). A big enough collapse and it's even more useless (who needs
microcontrollers when you're running away from cannibals).

But if the collapse magnitude is right, then this project will change the
course of our history, which makes it worth trying.

This idea is also fragile because it might not be feasible. It's also difficult
to predict post-collapse conditions, so the "self-contained" part might fail
and prove useless to many post-collapse communities.

But nevertheless, this idea seems too powerful to not try it. And even if it
proves futile, it sounds like a lot of fun to try.

## Organisation of this repository

There's very little done so far, but here's how it's organized:

* `parts`: Pieces of code to be assembled by the user into an OS.
* `recipes`: collection of recipes that assemble parts together on a specific
             machine.
* `doc`: User guide for when you've successfully installed Collapse OS.

Each folder has a README with more details.

## Roadmap

The project is progressing well and I already have a working shell (see `doc`
to see what it can do) on a classic RC2014.

However, such a vast project involves quite a lot of fiddling and I can't really
have a precise roadmap, only a general direction:

The primary target for Collapse OS is the z80 architecture. There's a good
amount of great z80-related hacks all around the internet, and the z80 CPU is
very scavenge-friendly: it's been (and is) included in tons of devices.

After a good proof of concept is done in z80, then more architectures can be
added into the mix. I have the intuition that we can mix AVR and z80 in a very
elegant minimal and powerful machine and it would be great if a Collapse OS
spawn could be built for such machine.

I'm planning to go forward with this project by doing three things:

1. Gather knowledge and hone skills.
2. Build useful parts of code to be assembled into an OS by the user.
3. Write "recipes", examples of assembly on real machines using parts I wrote
   to serve as a guide for post-collapse assembly.

Recipes should contain both "pre-collapse" instructions (how to build Collapse
OS from a "modern" system) and "post-collapse" instructions (how to build
Collapse OS from itself).

Initially, we of course only have "pre-collapse" instructions, but as tooling
improve, the "post-collapse" part will become more and more complete. When we
have complete "post-collapse" recipes, we can call it a win.

If you're interested in being part of this project, I have no idea how to
include you, but please, let me know, we'll manage something.

## 32-bit? 16-bit?

Why go as far as 8-bit machines? There are some 32-bit ARM chips around that
are protoboard-friendly.

First, because I think there are more scavenge-friendly 8-bit chips around than
scavenge-friendly 16-bit or 32-bit chips.

Second, because those chips will be easier to replicate in a post-collapse fab.
If the first chips we're able to create post-collapse are low-powered, we might
as well design a system that works well on low-powered chips.

That being said, nothing stops the project from including the capability of
programming an ARM or RISC-V chip.

That being said, the MSP430 seems like a really nice and widely used chip...

## Prior art

I've spent some time doing software archeology and see if something that was
already made could be used. There are some really nice and well-made programs
out there, such as CP/M, but as far as I know (please, let me know if I'm wrong,
I don't know this world very well), these old OS weren't made to be
self-replicating. CP/M is now open source, but I don't think we can recompile
CP/M from CP/M.

Then comes the idea of piggy-backing from an existing BASIC interpreter and
make a shell out of it. Interesting idea, and using Grant Searle's modified
nascom basic would be a good starting point, but I see two problems with this.
First, the interpreter is already 8k. That's a lot. Second, it's
copyright-ladden (by Searle *and* Microsoft) and can't be licensed as open
source.

Nah, maybe I'm working needlessly, but I'll start from scratch. But if someone
has a hint about useful prior art, please let me know.

## Risking ridicule

Why publish this hazy roadmap now and risk ridicule? Because I'm confident
enough that I want to pour significant efforts into this in the next few years
and because I have the intuition that it's feasible. I'm looking for early
feedback and possibly collaboration. I don't have a formal electronic training,
all my knowledge and experience come from fiddling as a hobbyist. If feasible
and relevant (who knows, IPCC might tell us in 10 years "good job, humans!
we've been up to the challenge! We've solved climate change!". Does this idea
sound more or less crazy to you than what you've been reading in this text so
far?), I will probably need help to pull this off.

[searle]: http://searle.hostei.com/grant/z80/SimpleZ80.html
