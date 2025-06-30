my role Commands is export {
    has %.commands  is built(False);
    has @.primaries is built(False);
    has %.aliases   is built(False);
    has $.default   is required;
    has $.out       is built(:bind);
    has $.err       is built(:bind);
    has $.sys       is built(:bind);
    has Bool $.catch is rw = True;
    has $.tokenizer    = *.words;
    has $.commandifier = False;
    has int $!max-words;

    # Put all the commands in the right place
    method TWEAK(:$commands!) {
        for $commands<> {
            $_ ~~ Pair:D | Callable:D
              ?? self.add-command($_)
              !! die "Don't know what to do with: $_.raku()";
        }
    }

    # Make sure these return something sensible
    method out(Commands:D:) { $!out // $*OUT }
    method err(Commands:D:) { $!err // $*ERR }
    method sys(Commands:D:) { $!sys // $!err // $*ERR }

    # Add a single command
    multi method add-command(Commands:D: Callable:D $_) {
        self.add-command(.name => $_, |%_)
    }
    multi method add-command(Commands:D: Pair:D $_, :$no-shortcuts) {
        my %commands  := %!commands;
        my @primaries := @!primaries;
        my %aliases   := %!aliases;

        my $value := .value;
        if .key.trim -> $command {
            my @words = $command.words;
            $!max-words max= @words.elems;

            my $main     := @words.shift;
            my $rest     := @words ?? " @words.join(' ')" !! "";
            my $referrer := $main ~ $rest;
            if %commands{$referrer}:!exists {
                @primaries.push($referrer);
                %aliases{$value}.push($referrer) if $value ~~ Str;
            }
            %commands{$referrer} := $value;

            # We want shortcuts
            unless $no-shortcuts {
                my int $i;
                my int $chars = $main.chars;
                while ++$i < $chars {
                    my str $name = "$main.substr(0,$i)$rest";
                    %commands.push($name => $referrer)
                      unless %commands{$name} ~~ Callable;
                }
            }
        }
        else {
            %commands.push("", $value);
        }
    }

    # Create a new Commands object for extended help texts
    method extended-help-from-hash(
      Commands:D: %explanations,
      :$default = { say "No extended help available for: $_" },
      :$handler = { say "More information about: $^key\n$^text" }
    ) {
        Commands.new(
          default  => $default,
          commands => @!primaries.map( -> $key {
              if %explanations{$key} -> $text {
                  my @additions;
                  @additions.push: $key => { $handler($key, $text) }
                  if %!aliases{$key} -> $alias {
                      @additions.push: $alias => { $handler($alias, $text) }
                  }
                  @additions.Slip
              }
          }).List
        )
    }

    # Process a line, possibly consisting of multiple commands
    method process(Commands:D: Str:D $line --> Nil) {
        if $!commandifier {
            my $seen-next;
            my $seen-last;
            for $!commandifier($line) {
                CONTROL {
                    # Remember if we've seen a "last"
                    $seen-next = True when CX::Next;
                    $seen-last = True when CX::Last;
                }
                self!command($_);
            }

            # Propagate any "next" and "last" to outer loop
            next if $seen-next;
            last if $seen-last;
        }
        else {
            self!command($line);
        }
    }

    # Resolve a given command to its final full name
    method resolve-command(Str:D $command is copy) {
        my %commands := %!commands;

        loop {
            if %commands{$command} -> $next {

                # Found the final target
                $next ~~ Callable
                  ?? (return $command)
                  # Got a collision
                  !! $next ~~ List
                    ?? (return Nil)
                    !! ($command = $next);
            }

            # Huh?  Internal messup
            else {
                return Nil;
            }
        }
    }

    method !command($command --> Nil) {
        my %commands := %!commands;

        my $target;
        my @words is List = $!tokenizer($command);
        if @words {
            my int $checks = @words.elems min $!max-words;

            # Get the initial target
            while $checks && !$target {
                $target := %commands{@words.head($checks--).join(" ")}<>;
            }
        }
        else {
            $target := %commands{""};
        }

        # Got a collision
        if $target ~~ List {
            self.sys.say("Ambigous command '$command', matches:");
            self.sys.say("  $_") for $target.sort(*.fc);
            return;
        }

        # Trace back to the final target if not final yet
        elsif $target ~~ Str {
            until $target ~~ Callable {
                if %commands{$target} -> $next {
                    $target := $next;
                }
                else {
                    self.sys.say("Could not find destination for '$target'");
                    return;
                }
            }
        }

        $target := $!default without $target;
        {
            my $*INPUT    := $command;
            my $*COMMANDS := self;
            temp $*OUT = self.out;
            temp $*ERR = self.err;
            if $!catch {
                try $target(@words);
                $*ERR.say(.message.chomp) with $!;
            }
            else {
                $target(@words);
            }
        }
    }

    method commands( Commands:D:) { %!commands.Map         }
    method primaries(Commands:D:) { @!primaries.sort(*.fc) }
    method aliases(  Commands:D:) { %!aliases.Map          }
}

# vim: expandtab shiftwidth=4
