my role primary { has $.is-primary }

my role Commands is export {
    has %.commands is built(False);
    has $.default  is required;
    has $.out      is built(:bind);
    has $.err      is built(:bind);
    has $.sys      is built(:bind);
    has Bool $.catch is rw = True;
    has $.tokenizer    = *.words;
    has $.commandifier = False;
    has int $!max-words;

    # Put all the commands in the right place
    method TWEAK(:$commands!) {
        for $commands<> {
            $_ ~~ Pair
              ?? self.add-command($_)
              !! die "Don't know what to do with: $_.raku()";
        }
    }

    # Make sure these return something sensible
    method out(Commands:D:) { $!out // $*OUT }
    method err(Commands:D:) { $!err // $*ERR }
    method sys(Commands:D:) { $!sys // $!err // $*ERR }

    # Add a single command
    method add-command(Commands:D: Pair:D $_) {
        my %commands := %!commands;
        my $value    := .value but primary(True);

        if .key.trim -> $command {
            my @words = $command.words;
            $!max-words max= @words.elems;

            my $main     := @words.shift;
            my $rest     := @words ?? " @words.join(' ')" !! "";
            my $referrer := $main ~ $rest;
            %commands{$referrer} := $value;

            my int $i;
            my int $chars = $main.chars;
            while ++$i < $chars {
                %commands.push("$main.substr(0,$i)$rest" => $referrer);
            }
        }
        else {
            %commands.push("", $value);
        }
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

    method commands(Commands:D:) {
        %!commands.Map
    }
    method primaries(Commands:D:) {
        %!commands.map({ .key if .value.?is-primary }).sort(*.fc)
    }
}

# vim: expandtab shiftwidth=4
