# User applications

This folder contains code designed to be "userspace" application. Unlike the
kernel, which always stay in memory. Those apps here will more likely be loaded
in RAM from storage, ran, then discarded so that another userspace program can
be run.

That doesn't mean that you can't include that code in your kernel though, but
you will typically not want to do that.

## Userspace convention

We execute a userspace application by calling the address it's loaded into. This
means: a userspace application is expected to return.

Whatever calls the userspace app (usually, it will be the shell), should set
HL to a pointer to unparsed arguments in string form, null terminated.

The userspace application is expected to set A on return. 0 means success,
non-zero means error.
