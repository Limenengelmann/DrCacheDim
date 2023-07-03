package DrCachesim;

use strict;
use warnings;

use File::Temp qw/ tempfile /;
use List::Util qw( min max reduce );
use Storable qw(dclone);
use YAML qw/ Load LoadFile Dump DumpFile /;
use Term::ANSIColor;
use POSIX;

our $DRDIR="/home/elimtob/.local/opt/DynamoRIO";
our $TMPDIR = "/tmp/drcachesim";
system("mkdir $TMPDIR") unless -d $TMPDIR;
our $RESDIR="/home/elimtob/Workspace/mymemtrace/results";

our @LVLS=("L1I", "L1D", "L2", "L3");
our $LINE_SIZE=64;
#default cost
our @DEFAULT_COST=(
    1000, #998.69,  # L1Isets
    2000, #1998.65, #L1Iassoc 
    1000, #998.69 , # L1Dsets 
    2000, #1998.65, #L1Dassoc 
    100 , #99.07  , #  L2sets 
    200 , #198.98 , # L2assoc 
    10  , #9.35   , #  L3sets 
    20  , #19.48  , # L3assoc 
);

#TODO store simulations in sqlite instead of yaml

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
           "Hits"              => 0, #undef,
           "Misses"            => 0, #undef,
           "Compulsory misses" => 0, #undef,
           "Invalidations"     => 0, #undef,
           "Miss rate"         => 0, #undef,
           "Child hits"        => 0, #undef,
       }
   };
   #XXX: Julia YAML package cannot deserialize this
   #bless $self, $class;
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
        LAT  => undef,
        VAL  => undef,
        COST => undef,
        cmd  => undef,
        "Total miss rate" => undef,
   };
   #XXX: Julia YAML package cannot deserialize this
   #bless $self, $class;
   return $self;
}

sub print_hierarchy {
    my $H = shift;

    my $size0 = $H->{L1I}->{cfg}->{size};
    my $ways0 = $H->{L1I}->{cfg}->{assoc};
    my $size1 = $H->{L1D}->{cfg}->{size};
    my $ways1 = $H->{L1D}->{cfg}->{assoc};
    my $size2 = $H->{L2}->{cfg}->{size};
    my $ways2 = $H->{L2}->{cfg}->{assoc};
    my $size3 = $H->{L3}->{cfg}->{size};
    my $ways3 = $H->{L3}->{cfg}->{assoc};
                                           
    my $sets0 = $size0 / $ways0 / $LINE_SIZE;
    my $sets1 = $size1 / $ways1 / $LINE_SIZE;
    my $sets2 = $size2 / $ways2 / $LINE_SIZE;
    my $sets3 = $size3 / $ways3 / $LINE_SIZE;

    my $cost = $H->{COST} || 0;
    my $lat  = $H->{LAT} || 0;
    my $val  = $H->{VAL} || 0;

    printf("%4d %2d %4d %2d %5d %2d %5d %2d | %9d %9d %9d\n",
        $sets0, $ways0,
        $sets1, $ways1,
        $sets2, $ways2,
        $sets3, $ways3,
        $cost, $lat, $val
    );
}

sub set_sets_ways {
    my $H = shift;
    my @V = (@_);

    foreach my $l (@LVLS) {
        my $s = shift @V || die "[set_sets_ways] Not enough args.";
        my $w = shift @V || die "[set_sets_ways] Not enough args.";

        $H->{$l}->{cfg}->{size} = $s*$w*$LINE_SIZE;
        $H->{$l}->{cfg}->{assoc} = $w;
    }
}

sub get_cmd {
    my $exe = shift;
    my $simcfg = shift || "";
    my $drargs = shift || "";
    $simcfg = "-config_file \"$simcfg\"" unless $simcfg eq "";
    #TODO maybe just join
    my $cmd = qq# drrun -root "$DRDIR"
                        -t drcachesim
                        -ipc_name $TMPDIR/drcachesim_pipe$$
                        $simcfg
                        $drargs
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

sub log2 {
    if (wantarray()) { # list context
        my @N = @_;
        my @res = map {log2($_)} @N;
    } else {
        my $n = shift;
        return floor(log($n)/log(2));
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

sub default_lat {
    # evaluate "goodness" of a hierarchy by simply weighing off size of the cash and average miss rate
    my $H = shift;
    my $L1I = $H->{L1I};
    my $L1D = $H->{L1D};
    my $L2  = $H->{L2};
    my $L3  = $H->{L3};

    print "Warning: L1D->{lat}    undefined\n" if not defined $L1D->{lat};
    print "Warning: L1D->{'Hits'} undefined\n" if not defined $L1D->{stats}->{Hits};
    print "Warning: L2->{lat}     undefined\n" if not defined $L2->{lat};
    print "Warning: L3->{lat}     undefined\n" if not defined $L3->{lat};
    print "Warning: H->{MML}      undefined\n" if not defined $H->{MML};
    print "Warning: L2->{'Hits'}  undefined\n" if not defined $L2->{stats}->{Hits};
    print "Warning: L3->{'Hits'}  undefined\n" if not defined $L3->{stats}->{Hits};

    # old AMAT code
    #my $AMAT = $L1D->{lat}
    #           + ($L1D->{stats}->{"Misses"} + $L1I->{stats}->{"Misses"})
    #           / ($L1D->{stats}->{"Misses"} + $L1I->{stats}->{"Misses"} + $L1D->{stats}->{"Hits"} + $L1I->{stats}->{"Hits"})
    #           * ($L2->{lat} +  $L2->{stats}->{"Miss rate"}
    #           * ($L3->{lat} +  $L3->{stats}->{"Miss rate"}
    #           * $H->{MML}));

    #XXX changed to absolute latency for simplicity
    my $lat = $L1D->{lat}*$L1D->{stats}->{Hits} +
               $L1I->{lat}*$L1I->{stats}->{Hits} +
               $L2->{lat}*$L2->{stats}->{Hits} +
               $L3->{lat}*$L3->{stats}->{Hits} +
               $H->{MML}*$L3->{stats}->{Misses};

    return $lat;
}

sub get_lin_cost_fun {
    my $cost = shift;
    my $cost_fun = sub {
        my $H = shift;
        my $L1I = $H->{L1I};
        my $L1D = $H->{L1D};
        my $L2  = $H->{L2};
        my $L3  = $H->{L3};
        my $val = $L1I->{cfg}->{size}/$LINE_SIZE/$L1I->{cfg}->{assoc}*$cost->[0] +
                  $L1I->{cfg}->{assoc}*$cost->[1] +
                  $L1D->{cfg}->{size}/$LINE_SIZE/$L1D->{cfg}->{assoc}*$cost->[2] +
                  $L1D->{cfg}->{assoc}*$cost->[3] +
                  $L2->{cfg}->{size}/$LINE_SIZE/$L2->{cfg}->{assoc}*$cost->[4] +
                  $L2->{cfg}->{assoc}*$cost->[5] +
                  $L3->{cfg}->{size}/$LINE_SIZE/$L3->{cfg}->{assoc}*$cost->[6] +
                  $L3->{cfg}->{assoc}*$cost->[7];
        return $val;
    };
    return $cost_fun;
}

sub default_cost {
    my $H = shift;
    my $L1I = $H->{L1I};
    my $L1D = $H->{L1D};
    my $L2  = $H->{L2};
    my $L3  = $H->{L3};
    my $val = $L1I->{cfg}->{size}/$LINE_SIZE/$L1I->{cfg}->{assoc}*$DEFAULT_COST[0] +
              $L1I->{cfg}->{assoc}*$DEFAULT_COST[1] +
              $L1D->{cfg}->{size}/$LINE_SIZE/$L1D->{cfg}->{assoc}*$DEFAULT_COST[2] +
              $L1D->{cfg}->{assoc}*$DEFAULT_COST[3] +
              $L2->{cfg}->{size}/$LINE_SIZE/$L2->{cfg}->{assoc}*$DEFAULT_COST[4] +
              $L2->{cfg}->{assoc}*$DEFAULT_COST[5] +
              $L3->{cfg}->{size}/$LINE_SIZE/$L3->{cfg}->{assoc}*$DEFAULT_COST[6] +
              $L3->{cfg}->{assoc}*$DEFAULT_COST[7];
    return $val;
}

sub default_val {
    my $H = shift;
    die "[default_val] Cannot calc objective val. Uninitialized cost or lat!" if not defined $H->{COST} or not defined $H->{LAT};
    return $H->{COST} + $H->{LAT};
}

sub get_max_lat_val {
    my $max_lat = shift;
    my $val_fun = sub {
        my $H = shift;
        die "[max_lat_val] Cannot calc objective val. Uninitialized cost or lat!" if not defined $H->{COST} or not defined $H->{LAT};
        #TODO some max cost or max lat value should be obtainable from a worst case scenario (100% miss rate)
        my $penalty = $H->{LAT} > $max_lat ? 1e9 : 0;
        return $H->{COST} + $H->{LAT} + $penalty;
    };
    return $val_fun;
}

sub default_problem {
    my $exe = shift || "";
    my $drargs = shift || "";
    my $defp = {
        exe  => sub { return ($exe, $drargs); },
        cost => \&default_cost,
        lat => \&default_lat,
        val  => \&default_val,
    };
    return $defp;
}


sub get_best {
    my $S = shift; 
    my $min = reduce { $a->{VAL} < $b->{VAL} ? $a : $b } @$S;
    return $min;
}

sub update_simulations {
    # Update non-simulated parameters like latency or AMAT
    # for all simulations in the given folder
    my $folder = shift;
    my $P = shift;

    my $fglob = "*.yml";
    my $all = `find $folder -name "$fglob" -type f`;
    my @list = split "\n", $all;
    foreach my $fname (@list) {
        print "Loading $fname\n";
        my $s = LoadFile($fname) or die "update_simulations: Can't load '$fname': $!";
        foreach my $H (@$s) {
            $H->{LAT} = $P->{lat}->($H);
            $H->{VAL}  = $P->{val}->($H);
        }
        print "Writing back $fname\n";
        DumpFile($fname, $s) or die "update_simulations: Can't dump '$fname': $!";
    }
}

sub create_cfg {
    my $H      = shift;
    #our $KEEP_ALL = 0;  # delete tmpfile at end of run
    my ($fh, $fname) = tempfile("drcachesim_cfgXXXX", DIR => $TMPDIR, UNLINK => 1);

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
        if (not defined $kv){
            print(Dump($H));
            die "Cannot create config, hierarchy likely malformed";
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

sub brutef_sweep {
    
    my %args = @_;
    my $HP = $args{H};  # prototype, fills in potentially missing params

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
        my $H = defined $HP ? dclone($HP) : new_hierarchy();
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

sub run_cachesim {
    #my $k = shift;
    my $P = shift;
    my $H = shift;
    my $simcfg = create_cfg($H);
    my ($exe, $drargs) = $P->{exe}->();
    my $cmd = get_cmd($exe, $simcfg, $drargs);
    #print "Executing: $cmd\n";
    #print "Before: " . Dumper($H);
    my ($ret, $cmdout) = run_and_parse_output($cmd, $H, $drargs); #print $cmdout;
    #print "After: " . Dumper($H);
    if ($ret != 0) {
        my $msg = "[run_cachesim#$$]: run and parse returned $ret. Command failed: $!";
        my $h = Dump($H);
        die "$msg\nCommand output: $cmdout\nCommand: $cmd\nConfig:$h\n";
    }
    $H->{LAT} = $P->{lat}->($H);
    $H->{COST} = $P->{cost}->($H);
    $H->{VAL}  = $P->{val}->($H);
}

sub run_analysistool {
    my $P = shift;
    my $tool = shift;
    my ($exe, $drargs) = $P->{exe}->();
    #TODO handle potential duplicate simulator type
    $drargs ||= "";
    $drargs .= " $tool";
    my $cmd = get_cmd($exe, "", $drargs);
    print("Running: $cmd\n");
    system($cmd);
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
    my $ret = 1;
    #TODO rename to clarify cmdout vs cmd_out
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
            my ($k, $v) = $l =~ s/(\d),(\d)/$1$2/gr =~ /\s+([\w\s]+):\s+([\d.]+)%?/;
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

sub parallel_run {
    my $P    = shift;
    my $sweep = shift or die "[parallel_run] Missing sweep arg!";
    my $procs = shift || `nproc --all`;
    chomp $procs;

    my $len = @$sweep;
    die "[parallel_run] Empty sweep!" if $len == 0;
    $procs = $len if $len < $procs;
    my $share = $len / $procs;

    print "parallel_sweep with $procs procs and $len configs\n";

    pipe(my $reader, my $writer);

    #TODO trap SIGINT for graceful shutdown
    my @pids = ();
    for(my $p=0; $p<$procs; $p++){
        my ($b1, $b2) = ($p*$share, ($p+1)*$share -1);
        my @slice = @$sweep[$b1 .. $b2];
        my $slen = @slice;
        #print "proc $p: Share from $b1 to $b2 (length slice: $slen, slice: $s)\n";
        my $pid = fork;
        if ($pid == 0) {
            close $reader;

            foreach my $H (@slice) {
                run_cachesim $P, $H;
                #print Dump($H);
                print $writer "\n"; # notify main process
            }
            #FIXME strips object type
            #XXX: Does that really matter? Maybe for loading, but even then we dont really care about it
            DumpFile("$TMPDIR/drcachesim_$$.yml", \@slice) or die "parallel_sweep: Can't open file: $!";
            close $writer;
            exit 0;
        }
        push @pids, $pid;
    }

    close $writer;
    # check progress
    my $count = 0;
    my $tic = time();
    my $time_left = -1;
    do {
        my $took = max(time() - $tic, 1e-9);    # avoid div by zero
        my $sim_speed = $count / $took;
        $time_left = ($len-$count) / $sim_speed if $sim_speed > 0;
        printf "%d/%d simulations done in %.1fs, %.1fs left (%.1f sims/s)\r", $count, $len, $took, $time_left, $sim_speed;
        STDOUT->flush();
        $count++;
    } while (my $c = <$reader>);
    print "\n";

    @$sweep = ();   # empty the sweep
    foreach my $p (@pids) {
        waitpid $p, 0;
        my $fname = "$TMPDIR/drcachesim_$p.yml";
        die "parallel_sweep: Error in process $p: Missing output file '$fname'. Aborting" unless -e $fname;
        #my $s = `cat /tmp/${x}_sim_$p`;
        #$s = eval "my " . $s or die "eval failed: $@";
        my $s = LoadFile($fname) or die "parallel_sweep: Can't load tmp results: $!";
        push @$sweep, @$s;
        `rm $fname`;
    }

    if (wantarray()) { # return sweep in list context
        return @$sweep; # potentially unnecessary deep copy
    } else {  # return filename in scalar context
        # collect results and store in RESDIR
        my $rfile = "$RESDIR/drcachesim_$$.yml";
        DumpFile($rfile, $sweep) or die "parallel_sweep: Can't load tmp results: $!";
        return $rfile;
    }
}
