# ed - line editor

Collapse OS's `ed` is modeled after UNIX's ed (let's call it `Ued`). The goal
is to have an editor that is tight on resources and that doesn't require
ncurses-like screen management.

In general, we try to follow `Ued`'s conventions and the "Usage" section is
mostly a repeat of `Ued`'s man page.

## Differences

There are a couple of differences with `Ued` that are intentional. Differences
not listed here are either bugs or simply aren't implemented yet.

* Always has a prompt, `:`.
* No size printing on load
* Initial line is the first one
* Line input is for one line at once. Less scriptable for `Ued`, but we can't
  script `ed` in Collapse OS anyway...
* For the sake of code simplicity, some commands that make no sense are
  accepted. For example, `1,2a` is the same as `2a`.

## Usage

`ed` is invoked from the shell with no argument. ed takes no argument.
It reads from the currently selected blkdev and writes to it.

In normal mode, `ed` waits for a command and executes it. If the command is
invalid, a line with `?` is printed and `ed` goes back to waiting for a command.

A command can be invalid because it is unknown, malformed or if its address
range is out of bounds.

### Commands

* `(addrs)p`: Print lines specified in `addrs` range. This is the default
  command. If only `(addrs)` is specified, it has the same effect.
* `(addrs)d`: Delete lines specified in `addrs` range.
* `(addr)a`: Appends a line after `addr`.
* `(addr)i`: Insert a line before `addr`.
* `q`: quit `ed`

### Current line

The current line is central to `ed`. Address ranges can be expressed relatively
to it and makes the app much more usable. The current line starts at `1` and
every command changes the current line to the last line that the command
affects. For example, `42p` changes the current line to `42`, `3,7d`, to 7.

### Addresses

An "address" is a line number. The first line is `1`. An address range is a
start line and a stop line, expressed as `start,stop`. For example, `2,4` refer
to lines 2, 3 and 4.

When expressing ranges, `stop` can be omitted. It will then have the same value
as `start`. `42` is equivalent to `42,42`.

Addresses can be expressed relatively to the current line with `+` and `-`.
`+3` means "current line + 3", `-5, +2` means "address range starting at 5
lines before current line and ending 2 lines after it`.

`+` alone means `+1`, `-` means `-1`.
