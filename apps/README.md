# User applications

This folder contains code designed to be "userspace" application. Unlike the
kernel, which always stay in memory. Those apps here will more likely be loaded
in RAM from storage, ran, then discarded so that another userspace program can
be run.

That doesn't mean that you can't include that code in your kernel though, but
you will typically not want to do that.
