my role primary { has $.is-primary }

my role Commands is export {
    has %.commands is built(False);
    has $.default  is required;
    has $.out      is built(:bind);
    has $.err      is built(:bind);
    has $.sys      is built(:bind);
    has $.tokenizer    = *.words;
    has $.commandifier = *.split(";").map(*.trim);
    has int $!max-words;

    method TWEAK(:$commands) {
        $!out := $*OUT without $!out;
        $!err := $*ERR without $!err;
        $!sys := $!err without $!sys;

        for $commands<> {
            $_ ~~ Pair
              ?? self.add-command($_)
              !! die "Don't know what to do with: $_.raku()";
        }
    }

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
        my $seen-last;
        for $!commandifier($line) {
            CONTROL {
                # Remember if we've seen a "last"
                $seen-last = True when CX::Last
            }
            self!command($_, $line);
        }

        # Propagate any "last" to outer loop
        last if $seen-last;
    }

    method !command($command, $line --> Nil) {
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
            $!sys.say("Ambigous command '$command', matches:");
            $!sys.say("  $_") for $target.sort(*.fc);
            return;
        }

        # Trace back to the final target if not final yet
        elsif $target ~~ Str {
            until $target ~~ Callable {
                if %commands{$target} -> $next {
                    $target := $next;
                }
                else {
                    $!sys.say("Could not find destination for '$target'");
                    return;
                }
            }
        }

        my $*COMMANDS := self;
        $target := $!default without $target;
        try $target(@words);
        say .message.chomp with $!;
    }

    method primaries(Commands:D:) {
        %!commands.map({ .key if .value.?is-primary }).sort(*.fc)
    }
}

=finish

my $commands = Commands.new:
  default => { dd "default"; say .EVAL },
  commands => (
    quit => { dd "quit"; last },  # also allows "q", "qu", "qui"
    exit => "quit",    # handle same as "quit"
    "release all" => { say "all released" },
    release => { say "released $_.[1]" },
    red => { say "save" },
    sleep => { sleep .[1] // 1 },
    help => { .say for $*COMMANDS.primaries },
    "" => { say "same" },
  ),
;

dd $commands.commands;
$commands.add-command( "scream" => { say .skip.uc ~ "!" } );

$commands.process("scream hello");

loop {
    last without my $line = prompt("> ");
    $commands.process($line);
}

# vim: expandtab shiftwidth=4
