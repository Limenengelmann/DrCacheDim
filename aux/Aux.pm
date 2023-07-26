package Aux;

use strict;
use warnings;

our $ROOT    = "/home/elimtob/Workspace/drcachedim";
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

sub nice_size {
    my $size = shift || 0;
    my $nsize = "";
    my $nr_fmt = "%d";
    my $unit = "B";
    my $MB = 2**20;
    my $KB = 2**10;
    if ($size >= $MB) {
        $nr_fmt = "%.3f" if ($size % $MB != 0);
        $unit = "MB";
        $size/=$MB;
    } elsif ($size >= $KB) {
        $nr_fmt = "%.3f" if ($size % $KB != 0);
        $unit = "KB";
        $size/=$KB;
    }
    $nsize = sprintf "$nr_fmt $unit", $size;
    return $nsize;
}

sub hierarchy2latex {
    my $H = shift;
    my $name = shift || "";

    my $size0 = $H->{L1I}->{cfg}->{size};
    my $ways0 = $H->{L1I}->{cfg}->{assoc};
    my $size1 = $H->{L1D}->{cfg}->{size};
    my $ways1 = $H->{L1D}->{cfg}->{assoc};
    my $size2 = $H->{L2}->{cfg}->{size};
    my $ways2 = $H->{L2}->{cfg}->{assoc};
    my $size3 = $H->{L3}->{cfg}->{size};
    my $ways3 = $H->{L3}->{cfg}->{assoc};
                                           
    #my $sets0 = $size0 / $ways0 / $LINE_SIZE;
    #my $sets1 = $size1 / $ways1 / $LINE_SIZE;
    #my $sets2 = $size2 / $ways2 / $LINE_SIZE;
    #my $sets3 = $size3 / $ways3 / $LINE_SIZE;

    my $cost = $H->{COST} || 0;
    my $mat  = $H->{MAT} || 0;
    my $val  = $H->{VAL} || 0;


    printf("\\multirow{2}{*}{%6s}\n    & %s & %s & %s & %s\n    & \\multirow{2}{*}{%d} & \\multirow{2}{*}{%d} & \\multirow{2}{*}{%d}\\\\ \\cline{2-5}\n    &  %d-way &  %d-way &  %d-way &  %d-way & & &\\\\\n    \\hline\n",
        $name,
        nice_size($size0),
        nice_size($size1),
        nice_size($size2),
        nice_size($size3),
        $cost, $mat, $val,
        $ways0,
        $ways1,
        $ways2,
        $ways3,
    );
}

1;
