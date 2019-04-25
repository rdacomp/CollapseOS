# AVR parts

The idea with the AVR parts is that you will design peripherals plugged into
your z80 that are controlled by AVR microcontrollers.

AVR is a large family and although they all work more-or-less the same,
assembler code for one model can't be directly used on another model. Despite
this, parts are only written once. If the model you have on hand doesn't match,
you'll have to translate yourself.

There are also tons of possible variants to some of those parts. You could want
to implement a feature with a certain set of supporting ICs that aren't the
same as implemented in the part. We can't possibly cover all combinations. We
won't. We'll try to have a good variety of problems we solve so that you have
good material for mix-and-matching your own solution.
