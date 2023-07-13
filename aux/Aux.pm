package Aux;

use strict;
use warnings;

our $ROOT    = "/home/elimtob/Workspace/mymemtrace";
our $DRDIR   = "/home/elimtob/.local/opt/DynamoRIO";
our $TMPDIR  = "/tmp/drcachesim";
our $SPECDIR = "/home/elimtob/.local/opt/spec-cpu2017";
system("mkdir $TMPDIR") unless -d $TMPDIR;
our $RESDIR="$ROOT/results";
system("mkdir $RESDIR") unless -d $RESDIR;

# common simulation params
our $BIG_VAL = 1.0e32;  #Common large value for penalty terms
our $HEAD_ONLY_SIM = "-trace_after_instrs 100000 -exit_after_tracing 10000000";

sub get_tstamp {
    my @tstamp = reverse localtime;
    $tstamp[-5]++;  #??
    return join("-", @tstamp[-5 .. -1]);
}

sub beep_when_done {
    system("paplay /usr/share/sounds/purple/alert.wav");
}

sub notify_when_done {
    my $txt = shift || return;
    system("notify-send --urgency=critical \'$txt\'");
}

sub log2 {
    if (wantarray()) { # list context
        my @N = @_;
        my @res = map {log2($_)} @N;
    } else {
        my $n = shift;
        return int(log($n)/log(2) + 0.5);
    }
}

sub int_log2 {
    # inefficient, but works with float, int, always returns an int
    # and is also not called often
    my @N = @_;
    my @res = ();

    foreach my $n (@N) {
        my $r = 1;
        while ($n >= 2**$r) {
            $r++;
        }
        push @res, $r-1;
    }
    return \@res;
}

sub gcd2p {
    # returns largest power of 2 that divides $v
    use integer;
    my $v = shift;
    my $k = 1;
    while ($v % (2*$k) == 0) {
        $k*=2;
    };
    return $k;
}

1;
