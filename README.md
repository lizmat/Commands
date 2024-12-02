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
    quit  => { last },  # also allows "q", "qu", "qui"
    exit  => "quit",    # handle same as "quit"
    shout => { say .skip.uc ~ "!" },
    sleep => { sleep .[1] // 1 }
    ""    => { say "assume same" },
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

DECLARATIONS
============

The declarations of possible actions can be done at object instantion (with the `:commands` named argument) or be added later at run-time (possibly interactively) with the `add-command` method.

METHODS
=======

new
---

```raku
# Set up commands
my $commands = Commands.new:
  catch    => True,
  default  => { say .EVAL },
  commands => (
    quit  => { last },  # also allows "q", "qu", "qui"
    exit  => "quit",    # handle same as "quit"
    shout => { say .skip.uc ~ "!" },
    ...
  ),
  out => $*OUT,  # default: $*OUT at moment of .process(...)
  err => $*ERR,  # default: $*ERR at moment of .process(...)
  sys => $.err,  # default: self.err at moment of .process(...)
  tokenizer    => *.words,
  commandifier => *.split(";").map(*.trim),  # default: False
;
```

### :commands

Required. The `:commands` named argument expects a list of `Pairs` of which the key determines the command, and the value determines the associated action to be performed. The action to be performed can be an actual `Callable`, or a string indicating the command the given key is an alias to.

If a `Callable` is specified, then it should expect a single positional argument: a `List` of the "tokens" as entered by the user (which defaults to executing the `.words` method on the input string). Not specifying parameters on the `Callable` is generally enough, especially if one is not interested in any additional arguments.

### :default

Required. The `:default` named argument expects a single `Callable` to be executed if an input could not be interpreted to be any of the known commands.

### :catch

Optional. The `:catch` named argument indicates whether any exceptions should be caught, and have just their message shown. It defaults to `True`. If `False` was specified, any exception will terminate the program, and produce a stack trace.

### :out

Optional. The `:out` named argument specifies the value of `$*OUT` whenever a command is executed. If not specified, or specified with an undefined value, will assume the value of $*OUT at command execution time.

### :err

Optional. The `:err` named argument specifies the value of `$*ERR` whenever a command is executed. If not specified, or specified with an undefined value, will assume the value of $*ERR at command execution time.

### :sys

Optional. The `:sys` named argument specifies the output handle to be used for system messages, such as when a shortened command entered by the user turned out to be ambiguous. It defaults to the (implicit) value specified with `:err`.

### :tokenizer

Optional. The `:tokenizer` named argument specifies how a user input line should be parsed into tokens. It should be specified with a `Callable`. It defaults to `*.words`.

### :commandifier

Optional. The `:commandifier` named argument specifies how a user input line should be separated into multiple commands. It should be specified with a `Callable`. It defaults to `False`, indicating that each line passed to "process" should always be seen as a single command.

add-command
-----------

```raku
$commands.add-command( "sleep" => { sleep .[1] // 1 } );
```

The `add-command` method allows one to add a command to the existing command structure during the lifetime of the `Commands` object. It expects a `Pair` argument, just as in the `List` specified with the `:commands` named argument at object instantion.

resolve-command
---------------

```raku
say $commands.resolve-command("foo");
```

The `resolve-command` method is a helper method that will either expand the given command, or return `Nil` if it couldn't for whatever reason.

process
-------

```raku
loop {
    last without my $line = prompt("> ");
    $commands.process($line);
}
```

The `process` method takes a single string argument, attempts to process it as one or more command statements. Each command is then tokenized and an associated action `Callable` is selected.

If no direct action could be identified, the shortened versions of the first token will tried. If that also fails, the default action will be assumed.

It then sets the these dynamic variables:

  * $*INPUT - the non-tokenized original command statement

  * $*COMMANDS - the Commands object

  * $*OUT - the value (implicitely) specified with :out

  * $*ERR - the value (implicitely) specified with :err

And then executes the associated action `Callable` with the `List` of tokens passed as the single argument. If the execution failed for any reason, the associated error message will be shown using the value (implicitely) specified with `:err` at instantiation.

primaries
---------

```raku
my $commands = Commands.new:
  default => { say .EVAL },
  commands => (
    ...
    help => { .say for $*COMMANDS.primaries },
    ...
  ),
;
```

The `primaries` method returns a sorted list of primary commands (that is: commands that specified). It is intended to provide basic "help" support.

aliases
-------

```raku
my $commands = Commands.new:
  default => { say .EVAL },
  commands => (
    quit => { last },
    exit => "quit",
    ...
  ),
;

say "$_.key(): $_.value()" for $commands.aliases;  # quit: exit
```

The `aliases` method returns a (potentionally empty) `Map` with as keys the commands that have aliases, and as values a `List` of commands that are aliases to the command of the key.

commands
--------

The `commands` method returns a `Map` with the internal lookup structure. It is intended for debugging issues only.

default
-------

The `default` method returns the `Callable` that was specified with the `:default` named argument at object instantiation. It is intended for debugging issues only.

catch
-----

```raku
say $commands.catch;  # True

$commands.catch = False;
```

The `catch` method returns a `Bool` to indicate whether processing of a command is secured by a `CATCH` mechanism. It can also be called as a left-value to allow changing of the catch state.

Note that disabling the catch mechanism is usually done only in a debugging environment.

out
---

Returns the object that was (implicitely) specified with the `:out` named argument at object instantiation.

err
---

Returns the object that was (implicitely) specified with the `:err` named argument at object instantiation.

sys
---

Returns the object that was (implicitely) specified with the `:sys` named argument at object instantiation.

tokenizer
---------

Returns the `Callable` that was (implicitely) specified with the `:tokenizer` named argument at object instantiation.

commandifier
------------

Returns what was (implicitely) specified with the `:commandifier` named argument at object instantiation.

CREATING EXTENDED HELP
======================

Creating a "help" command is easy. Handling more in-depth help requests can be more complicated, like "help frobnicate" to get more help about the "frobnicate" command. But since commands can be shortened, e.g. to "frob", users might be inclined to enter "help frob" to get help about the "frobnicate" command.

The `extended-help-from-hash` instance method returns a new `Commands` object that can help with the "help frob" case, as well as the "help frobnicate" case.

All one needs to do is set up a hash where a key should match one of the commands of a `Commands` instance, and the value is a text to be shown when in-depth help is requested.

A simple case:

```raku
my constant %help =
  quit  => "Quit the editor and save the history",
  shout => "Say input in capitals with exclamation mark",
;

my $commands = Commands.new:
  default => { note "default: '$*INPUT'" },
  commands => (
    quit  => { last },
    exit  => "quit",
    shout => { say .skip.uc ~ "!" },
    help  => {
        state $help = $*COMMANDS.extended-help-from-hash(%help);
        if .skip.join(" ") -> $deeper {
            $help.process($deeper)
        }
        else {
            .say for $*COMMANDS.primaries;
        }
    },
  )
);

loop {
    last without my $line = prompt("> ");
    $commands.process($line);
}
```

    > help
    exit
    help
    quit
    shout
    > help quit
    More information about: quit
    Quit the editor and save the history
    > help sh
    More information about: shout
    Say input in capitals with exclamation mark
    > h e
    More information about: exit
    Quit the editor and save the history

To customize the handling further, it is possible to specify the following named arguments:

### :default

Specifies the `Callable` to be called if the in-depth help request could not be processed, with the same semantics as the <:default> named argument on `.new`.

### :handler

Specifies a `Callable` that will be called for an in-depth help request for which there is a help text. It is expected to receive two positional arguments: the full command name (e.g. "quit") and the associated text (e.g. "Quit the editor and save the history").

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Commands . Comments and Pull Requests are welcome.

If you like this module, or what I'm doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2024 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

