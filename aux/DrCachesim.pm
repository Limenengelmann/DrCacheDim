package DrCachesim;

use strict;
use warnings;
use File::Temp qw/ tempfile /;
use List::Util qw( min max );
use Storable qw(dclone);
use YAML qw/ Load LoadFile Dump DumpFile /;
use Term::ANSIColor;

our $DRDIR="/home/elimtob/.local/opt/DynamoRIO";

our @LVLS=("L1I", "L1D", "L2", "L3");
our $LINE_SIZE=64;

sub new_cache {
   my $class = "cache";
   my %args = @_;
   my $self = {
       lat => undef,
       cfg => { # keys need to be exact DrCachesim config params
           type           => $args{type},
           core           => $args{core},
           size           => $args{size},
           assoc          => $args{assoc},
           inclusive      => $args{inclusive},
           parent         => $args{parent},
           prefetcher     => "none",
           replace_policy => "LRU",
       },
       stats => {
           "Hits"              => undef,
           "Misses"            => undef,
           "Compulsory misses" => undef,
           "Invalidations"     => undef,
           "Miss rate"         => undef,
           "Child hits"        => undef,
       }
   };
   bless $self, $class;
   return $self;
}

sub new_hierarchy {
   my $class = "hierarchy";
   my $self = {
        L1I  => new_cache(type => "instruction", core => 0, parent => "L2"),
        L1D  => new_cache(type => "data", core => 0, parent => "L2"),
        L2   => new_cache(type => "unified", parent => "L3", inclusive => "false"),
        L3   => new_cache(type => "unified", parent => "memory", inclusive => "false"),
        MML  => 1000,    # TODO main memory latency
        AMAT => undef,
        cmd  => undef,
        "Total miss rate" => undef,
   };
   bless $self, $class;
   return $self;
}

sub drrun_cachesim {
    my $simcfg = shift;
    my $exe = shift;
    my $cmd = qq# drrun -root "$DRDIR"
                        -t drcachesim
                        -ipc_name /tmp/drcachesim_pipe$$
                        -config_file "$simcfg"
                        -- $exe#;

    return $cmd =~ s/\n/ /gr =~ s/  +/ /gr;
}

sub beep_when_done {
    system("paplay /usr/share/sounds/purple/alert.wav");
}

sub get_local_hierarchy {
    my $H = new_hierarchy();

    #TODO more precise way to do it via looking in /proc/.../cache
    my $out = `getconf -a | grep CACHE`;

    ($H->{L1I}->{cfg}->{size} ) = $out =~ /LEVEL1_ICACHE_SIZE\s*(\d+)/;
    ($H->{L1D}->{cfg}->{size} ) = $out =~ /LEVEL1_DCACHE_SIZE\s*(\d+)/;
    ($H->{L2}->{cfg}->{size}  ) = $out =~ /LEVEL2_CACHE_SIZE\s*(\d+)/;
    ($H->{L3}->{cfg}->{size}  ) = $out =~ /LEVEL3_CACHE_SIZE\s*(\d+)/;
    ($H->{L1I}->{cfg}->{assoc}) = $out =~ /LEVEL1_ICACHE_ASSOC\s*(\d+)/ || 8;
    ($H->{L1D}->{cfg}->{assoc}) = $out =~ /LEVEL1_DCACHE_ASSOC\s*(\d+)/;
    ($H->{L2}->{cfg}->{assoc} ) = $out =~ /LEVEL2_CACHE_ASSOC\s*(\d+)/;
    ($H->{L3}->{cfg}->{assoc} ) = $out =~ /LEVEL3_CACHE_ASSOC\s*(\d+)/;

    # WIP accurate latency calculation using range of sizes
    my $Lat;
    $Lat = `aux/random-chase` unless -e "config/random-chase.out";
    `echo '$Lat' > config/random-chase.out` unless -e "config/random-chase.out";
    $Lat = `cat config/random-chase.out` if -e "config/random-chase.out";
    my @S = ($Lat =~ /\s*(\d+)\s+[\d.]+/g);
    my @T = ($Lat =~ /\s*\d+\s+([\d.]+)/g);
    my @I = (0..$#S-1);

    foreach my $l (@LVLS) {
        $H->{$l}->{lat} = @T[max(grep({$S[$_] <= $H->{$l}->{cfg}->{size}} @I))];
    }

    $H->{L1I}->{lat} = $H->{L1D}->{lat};
    # TODO is this accurate
    $H->{MML} = $T[-1];
    return $H;
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

sub valid_config {
    # Check that a hierarchy can be simulated with dynamorio
    # And that the sizes make "sense", e.g. L1 < L2 < L3
    my $H = shift;
    my $L1I = $H->{L1I}->{cfg};
    my $L1D = $H->{L1D}->{cfg};
    my $L2 = $H->{L2}->{cfg};
    my $L3 = $H->{L3}->{cfg};

    # Rationale for ">" instead of ">=":
    # Since the simulator only supports sizes as powers of 2,
    # we might get situations, where the performance improves tremendously
    # between 2^(n-1) and 2^n, where n is the next levels size.
    # So those configurations should be allowed
    my $weird_size = $L1I->{size} > $L1D->{size} ||
                     $L1D->{size} > $L2->{size}  ||
                     $L2->{size}  > $L3->{size};
    my $bad_size = $L1I->{assoc} * $LINE_SIZE > $L1I->{size} ||
                   $L1D->{assoc} * $LINE_SIZE > $L1D->{size} ||
                   $L2->{assoc}  * $LINE_SIZE > $L2->{size}  ||
                   $L3->{assoc}  * $LINE_SIZE > $L3->{size};
    #print colored("Weird size\n", "red") if $weird_size;
    #print colored("Bad size\n", "red") if $bad_size;

    return not ($weird_size or $bad_size);
}

sub brutef_sweep {
    
    my %args = @_;
    my $HP = $args{H};

    # set default values
    foreach my $l (@LVLS) {
        unless (defined $args{$l}) {
            $args{$l} = int_log2($HP->{$l}->{cfg}->{size} , $HP->{$l}->{cfg}->{size},
                                 $HP->{$l}->{cfg}->{assoc}, $HP->{$l}->{cfg}->{assoc}); 
        }
    }

    my ($L1I_smin, $L1I_smax,
        $L1I_amin, $L1I_amax) = @{$args{L1I}};
    my ($L1D_smin, $L1D_smax,
        $L1D_amin, $L1D_amax) = @{$args{L1D}};
    my ($L2_smin, $L2_smax,
        $L2_amin, $L2_amax) = @{$args{L2}};
    my ($L3_smin, $L3_smax,
        $L3_amin, $L3_amax) = @{$args{L3}};

    #print "min: $L1I_smin, $L1D_smin, $L2_smin, $L3_smin, $L1I_amin, $L1D_amin, $L2_amin, $L3_amin\n";
    #print "max: $L1I_smax, $L1D_smax, $L2_smax, $L3_smax, $L1I_amax, $L1D_amax, $L2_amax, $L3_amax\n";

    my $count = ($L1I_smax-$L1I_smin+1)*($L1D_smax-$L1D_smin+1)*
                ($L2_smax-$L2_smin+1)  *($L3_smax-$L3_smin+1)*
                ($L1I_amax-$L1I_amin+1)*($L1D_amax-$L1D_amin+1)*
                ($L2_amax-$L2_amin+1)  *($L3_amax-$L3_amin+1);
    print "Warning: Generating up to $count Hierarchies!\n";

    my $ill = 0;
    my $S = ();
    for (my $s1I=2**$L1I_smin; $s1I<=2**$L1I_smax; $s1I*=2) {
    for (my $s1D=2**$L1D_smin; $s1D<=2**$L1D_smax; $s1D*=2) {
    for (my $s2 =2**$L2_smin ; $s2 <=2**$L2_smax ; $s2 *=2) {
    for (my $s3 =2**$L3_smin ; $s3 <=2**$L3_smax ; $s3 *=2) {
    for (my $a1I=2**$L1I_amin; $a1I<=2**$L1I_amax; $a1I*=2) {
    for (my $a1D=2**$L1D_amin; $a1D<=2**$L1D_amax; $a1D*=2) {
    for (my $a2 =2**$L2_amin ; $a2 <=2**$L2_amax ; $a2 *=2) {
    for (my $a3 =2**$L3_amin ; $a3 <=2**$L3_amax ; $a3 *=2) {
        my $H = $HP ? dclone($HP) : new_hierarchy();
        $H->{L1I}->{cfg}->{size}  = $s1I;
        $H->{L1D}->{cfg}->{size}  = $s1D;
        $H->{L2}->{cfg}->{size}   = $s2 ;
        $H->{L3}->{cfg}->{size}   = $s3 ;
        $H->{L1I}->{cfg}->{assoc} = $a1I;
        $H->{L1D}->{cfg}->{assoc} = $a1D;
        $H->{L2}->{cfg}->{assoc}  = $a2 ;
        $H->{L3}->{cfg}->{assoc}  = $a3 ;

        if (valid_config($H)) {
            push @$S, $H;
        } else {
            #print Dump($H);
            $ill++;
        }
    }}}}}}}}
    print "Skipped $ill/$count bad Hierarchies!\n" if $ill;
    return $S;
}

sub run_and_parse_output {
    my $cmd = shift;
    my $H   = shift;

    #$cmd    =~ s/ -- .*$/ -- echo 'babadibupi'/;
    #$cmd = "echo 'babadibupi'";

    # safe open to merge stderr and stdout (drcachesim outputs stats to stderr)
    my $pid = open my $cmdout, '-|';
    if ($pid == 0) {
        # child
        open STDERR, ">&", \*STDOUT  or die "Safe open failed: $!";
        exec $cmd or die "Exec failed: $!";
    }
    
    my $state = 0;
    my $c;
    my $ret = 0;
    my @cmd_out = ();
    while (my $l = <$cmdout>) {
        push @cmd_out, $l if $state == 0;    # only remember cmd out
        #print "$l";
        #print "State = $state\n";
        if ($state == 0 && $l =~ /---- <application exited with code (\d+)> ----/) {
            $ret = $1;
            last if $ret != 0; # on nonzero exit code
            $state = 1;
        } elsif ($state == 1) {
            ($c) = $l =~ /\s*(L1I|L1D|L2|L3) stats:/;
            $state = 2 if $c;
        } elsif ($state == 2) {
            if ($l =~ /\s*(L1I|L1D|L2|L3) stats:/) {
                $c = $1;
                next;
            }
            my ($k, $v) = $l =~ s/(\d),(\d)/$1$2/r =~ /\s+([\w\s]+):\s+([\d.]+)%?/;
            #print "k=$k, v=$v\n";
            die "Regex matching failed\n" if $k eq "" || $v eq "";
            if ($k eq "Total miss rate") {  # Store total missrate in hierarchy, not L3
                $H->{$k} = $v;
            } elsif ($k eq "Local miss rate") {   # L3 missrate has different naming for some reason
                $H->{$c}->{stats}->{"Miss rate"} = $v;
            } else {
                $H->{$c}->{stats}->{$k} = $v;
            }
        }
    }
    $H->{cmd} = $cmd;
    $ret = 1 if $state == 0;    # something definetely went wrong

    if (wantarray()) { # list context
        return ($ret, join("\n", @cmd_out));
    }
    else {
        return $ret;
    }
}

sub set_amat {
    # evaluate "goodness" of a hierarchy by simply weighing off size of the cash and average miss rate
    my $H = shift;
    my $L1I = $H->{L1I};
    my $L1D = $H->{L1D};
    my $L2 = $H->{L2};
    my $L3 = $H->{L3};

    #TODO how to include L1I latency as well
    my $AMAT =   $L1D->{lat} + $L1D->{stats}->{"Miss rate"}
               * ($L2->{lat} +  $L2->{stats}->{"Miss rate"}
               * ($L3->{lat} +  $L3->{stats}->{"Miss rate"}
               * $H->{MML}));
    print 'L1D->{lat}         undefined\n' if not defined $L1D->{lat};
    print 'L1D->{"Miss rate"} undefined\n' if not defined $L1D->{stats}->{"Miss rate"};
    print 'L2->{lat}          undefined\n' if not defined $L2->{lat};
    print 'L3->{lat}          undefined\n' if not defined $L3->{lat};
    print 'H->{MML}           undefined\n' if not defined $H->{MML};
    print 'L2->{"Miss rate"}  undefined\n' if not defined $L2->{stats}->{"Miss rate"};
    print 'L3->{"Miss rate"}  undefined\n' if not defined $L3->{stats}->{"Miss rate"};

    #print Dump($H);
    $H->{AMAT} = $AMAT;
    return $AMAT;
}

sub load_results {
#TODO load previous simulations in results folder
    1;
}

sub create_cfg {
    my $H      = shift;
    my $tmpdir = "/tmp";
    #our $KEEP_ALL = 0;  # delete tmpfile at end of run
    my ($fh, $fname) = tempfile("drcachesim_cfgXXXX", DIR => "/tmp", UNLINK => 1);

    my @C = ();
    my $params = qq#
        num_cores 1
    #;
    push @C, $params;

    foreach my $lvl (@LVLS) {
        my $c  = $H->{$lvl}->{cfg};
        my $kv = ();
        foreach my $k (keys(%$c)) {
            my $v = $c->{$k};
            # skip keys that map to references
            next unless defined $v and ref $v eq "";
            push @$kv, "\t$k $v";
        }
        $kv = join "\n", @$kv;
        my $l = qq#
            $lvl {
                $kv
            }
        #;
        push @C, $l;
    }
    my $cfg = join "", @C;
    $cfg =~ s/ {2,}/ /g;    # just for easier debugging

    print $fh "$cfg\n";
    return $fname;
}
