[![Actions Status](https://github.com/lizmat/Commands/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/Commands/actions) [![Actions Status](https://github.com/lizmat/Commands/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/Commands/actions) [![Actions Status](https://github.com/lizmat/Commands/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/Commands/actions)

NAME
====

Commands - handle interactive user commands

SYNOPSIS
========

```raku
use Commands;

# Set up commands
my $commands = Commands.new:
  default  => { say .EVAL },
  commands => (
    quit   => { last },  # also allows "q", "qu", "qui"
    exit   => "quit",    # handle same as "quit"
    scream => { say .skip.uc ~ "!" },
    sleep  => { sleep .[1] // 1 }
    ""     => { say "assume same" },
    "release all" => { say "all released" },
  ),
;

# Run a very simple REPL
loop {
    last without my $line = prompt("> ");
    $commands.process($line);
}
```

DESCRIPTION
===========

The `Commands` role provides a declarative way to handle (user) inputs in REPL-like environments. It allows this by describing the possible command interactions once (possibly at compile time) and the associated actions, and takes away the burden of figuring out all of the possible combinations of commands with possible shortcuts.

The main declarations consist of a list of `Pair`s where the key is the command, and the value is either e `Callable`, or a string referring to an other command (allowing a simple way to define aliases). The action to be performed if the user entered something that did not match any of the commands, can also be specified.

Specifying a command
--------------------

Each command consists of zero or more words. The user will be able to shortcut the first word of any command until it is no longer unique. So if we take the command set in the SYNOPSIS, the user can enter "sc" to execute the "scream" command, but cannot enter "s", because that would be ambiguous with "sleep". On the other hand, the user would be able to enter "r all", because only one command starts with "r", but would not be able to shorten "all" to "a", as only the first word of any command can be shortened.

If a `Callable` is specified, then it should expect a single positional argument: a `List` of the "tokens" as entered by the user (which defaults to executing the `.words` method on the input string). Not specifying parameters on the `Callable` is generally enough, especially if one is not interested in any additional arguments.

DECLARATIONS
============

The declarations of possible actions can be done at object instantion (with the `:commands` named argument) or be added later at run-time (possibly interactively) with the `add-command` method.

METHODS
=======

new
---

### :commands

### :default

### :tokenizer

### :commandifier

### :out

### :err

### :sys

add-method
----------

process
-------

primaries
---------

out
---

err
---

sys
---

tokenizer
---------

commandifier
------------

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Commands . Comments and Pull Requests are welcome.

If you like this module, or what I'm doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2024 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

