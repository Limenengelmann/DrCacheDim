package Optim;

use strict; 
use warnings;

use DrCachesim;
use YAML qw/ Load LoadFile Dump DumpFile /;

sub H2julia {
    #always expects a list of hierarchies
    my $S = shift;

    my $jS = ();

    foreach my $H (@$S) {
        my $size0 = $H->{L1I}->{cfg}->{size};
        my $ways0 = $H->{L1I}->{cfg}->{assoc};
        my $size1 = $H->{L1D}->{cfg}->{size};
        my $ways1 = $H->{L1D}->{cfg}->{assoc};
        my $size2 = $H->{L2}->{cfg}->{size};
        my $ways2 = $H->{L2}->{cfg}->{assoc};
        my $size3 = $H->{L3}->{cfg}->{size};
        my $ways3 = $H->{L3}->{cfg}->{assoc};

        my $sets0 = $size0 / $ways0 / $DrCachesim::LINE_SIZE;
        my $sets1 = $size1 / $ways1 / $DrCachesim::LINE_SIZE;
        my $sets2 = $size2 / $ways2 / $DrCachesim::LINE_SIZE;
        my $sets3 = $size3 / $ways3 / $DrCachesim::LINE_SIZE;

        my $jH = {
            H => [
                $size0,
                $ways0,
                $size1,
                $ways1,
                $size2,
                $ways2,
                $size3,
                $ways3,
            ],
            VAL => $H->{VAL},
            AMAT => $H->{AMAT},
        };
        push @$jS, $jH;
    }

    return Dump($jS);
}

sub julia2H {
    my $jS = shift;
    $jS = Load($jS);
    my $S = ();
    foreach my $jH (@$jS) {
        my $H = DrCachesim::get_local_hierarchy();

        my ($size0, $ways0,
            $size1, $ways1,
            $size2, $ways2,
            $size3, $ways3) = @{$jH->{H}};

        $H->{L1I}->{cfg}->{size}  = $size0;
        $H->{L1I}->{cfg}->{assoc} = $ways0;
        $H->{L1D}->{cfg}->{size}  = $size1;
        $H->{L1D}->{cfg}->{assoc} = $ways1;
        $H->{L2}->{cfg}->{size}   = $size2;
        $H->{L2}->{cfg}->{assoc}  = $ways2;
        $H->{L3}->{cfg}->{size}   = $size3;
        $H->{L3}->{cfg}->{assoc}  = $ways3;

        $H->{VAL} = $jH->{VAL};
        $H->{AMAT} = $jH->{AMAT};

        push @$S, $H;
    }
    return $S;
}

sub solve {
    my $P = shift;

    # test julia2H and H2julia
    my $H1 = DrCachesim::get_local_hierarchy();
    my $H2 = DrCachesim::get_local_hierarchy();
    $H2->{AMAT} = 1111;
    $H2->{VAL} = 2222;
    my $S = [$H1, $H2];

    my $test = Dump($S) eq Dump(julia2H(H2julia($S)));
    print("[Optim::solve] Test for equality (j2H H2j): $test\n");
    #TODO create 2 FIFO
    #TODO fork julia process
    #TODO loop over pname_in and simulate

    my $pname_SIM  = "$DrCachesim::TMPDIR/pipeSIM-$$";
    my $pname_RES = "$DrCachesim::TMPDIR/pipeRES-$$";
    system("mkfifo $pname_SIM $pname_RES") == 0 or die "[Optim::solve] Could not create pipes: $!";

    #my $S = LoadFile $pname_SIM;
    #my $rfile = DrCachesim::parallel_run $x, $sweep;
    
    # safe open to combine stdout and stderr
    #my $pid = open my $cmdout, '-|';
    #if ($pid == 0) {
    #    # child
    #    open STDERR, ">&", \*STDOUT  or die "Safe open failed: $!";
    #    exec $cmd or die "Exec failed: $!";
    #}
    
    #TODO proper pathing solution
    print("[Optim::solve] Forking child\n");
    my $pid = fork;
    if ($pid == 0) {
        print("[Optim::solve][child] Calling exec..\n");
        my $cmd = "julia aux/optim.jl $pname_SIM $pname_RES";
        #my $outp = `$cmd`;
        #print "JULIA START\n$outp\nJULIA END\n";
        exec $cmd or die "Exec failed: $!";
    }

    my $done = 0;
    my $pipe_RES; 
    my $pipe_SIM;

    while (not $done) {
        #TODO Decide if we r/w $H or filename pointing to yaml file
        #TODO test if we can pipe more than fits into the buffer
        #TODO check which closes are necessary/affect julia
        #XXX We need to close $pipe_RES after writing, so julia receives EOF
        print("[Optim::solve] Opening pipe_RES\n");
        open($pipe_RES, ">", $pname_RES) or die "[Optim::solve] Could not open $pname_RES: $!";
        print("[Optim::solve] Writing to pipe_RES...\n");
        print($pipe_RES H2julia($S));
        print("[Optim::solve] Done. Closing pipe_RES\n");
        close($pipe_RES);

        print("[Optim::solve] Opening pipe_SIM\n");
        open($pipe_SIM, "<", $pname_SIM) or die "[Optim::solve] Could not open $pname_SIM: $!";
        print("[Optim::solve] Reading from pipe_SIM...\n");
        #FIXME probably race condition if reading from pipe_SIM consecutively
        #XXX messages might merge
        my $s = join("", <$pipe_SIM>);  # how much does this read?
        print("[Optim::solve] Done reading from pipe_SIM...\n");
        #print("[Optim::solve] Got YAML:\n$s");
        my $S2 = julia2H($s);   #FIXME too slow if length($s) is large (either bc of get_local or load)
        # round-trip test
        $test = Dump($S) eq Dump($S2);
        print("[Optim::solve] Round-trip test: $test\n");
        print("[Optim::solve] Sleeping\n");
        #TODO random sleep
        sleep 0.7;
        print("[Optim::solve] Reading again\n");
        $s = join("", <$pipe_SIM>);
        $test = $s eq "DONE";
        $done = 1 if $s eq "DONE";
        print("[Optim::solve] Read '$s'. DONE? '$test'. Closing pipe_SIM\n");
        close($pipe_SIM);
    }

    print("[Optim::solve] Waiting for child\n");
    waitpid $pid, 0;

    system("rm $pname_SIM $pname_RES") == 0 or die "[Optim::solve] Could not remove pipes: $!";
    print("[Optim::solve] Exiting\n");
}

1;
