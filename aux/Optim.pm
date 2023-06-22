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
                $sets0,
                $ways0,
                $sets1,
                $ways1,
                $sets2,
                $ways2,
                $sets3,
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
    print $jS . "\n";
    $jS = Load($jS);
    my $len = @$jS;
    printf("New jS: $jS, length: %d\n", $len);
    my $S = [];
    foreach my $jH (@$jS) {
        my $H = DrCachesim::get_local_hierarchy();

        my ($sets0, $ways0,
            $sets1, $ways1,
            $sets2, $ways2,
            $sets3, $ways3) = @{$jH->{H}};

        $H->{L1I}->{cfg}->{size}  = $sets0*$ways0*$DrCachesim::LINE_SIZE;
        $H->{L1I}->{cfg}->{assoc} = $ways0;
        $H->{L1D}->{cfg}->{size}  = $sets1*$ways1*$DrCachesim::LINE_SIZE;
        $H->{L1D}->{cfg}->{assoc} = $ways1;
        $H->{L2}->{cfg}->{size}   = $sets2*$ways2*$DrCachesim::LINE_SIZE;
        $H->{L2}->{cfg}->{assoc}  = $ways2;
        $H->{L3}->{cfg}->{size}   = $sets3*$ways3*$DrCachesim::LINE_SIZE;;
        $H->{L3}->{cfg}->{assoc}  = $ways3;

        $H->{VAL} = $jH->{VAL};
        $H->{AMAT} = $jH->{AMAT};

        push @$S, $H;
    }
    my $len2 = @$S;
    printf("New S: $S, length: %d\n", $len2);
    return $S;
}

sub comm_test {
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
        exec $cmd or die "Exec failed: $!";
    }

    my $done = 0;
    my $pipe_RES;
    my $pipe_SIM;

    #XXX Keeping the pipes open permanently would ofc be more performant, 
    #   but this way opening acts as a synchronisation barrier
    #   I am also too lazy to handle incomplete writes and the bottleneck will be the simulation time anyway
    while (not $done) {
        print("[Optim::solve] Opening pipe_RES\n");
        #XXX Opening normally blocks until other pipe end is opened too
        open($pipe_RES, ">", $pname_RES) or die "[Optim::solve] Could not open $pname_RES: $!";
        print("[Optim::solve] Writing to pipe_RES...\n");
        print($pipe_RES H2julia($S));
        print("[Optim::solve] Done. Closing pipe_RES\n");
        #XXX We need to close $pipe_RES after writing, so julia receives EOF
        close($pipe_RES);

        print("[Optim::solve] Opening pipe_SIM\n");
        open($pipe_SIM, "<", $pname_SIM) or die "[Optim::solve] Could not open $pname_SIM: $!";
        print("[Optim::solve] Reading from pipe_SIM...\n");
        #XXX race condition if reading from pipe_SIM consecutively and other process writes consecutively
        #XXX messages might merge, so we avoid consecutive writes from julia and synchronise by opening pipe_RES
        my $s = join("", <$pipe_SIM>);
        print("[Optim::solve] Done reading from pipe_SIM...\n");
        print("[Optim::solve] Got YAML:\n$s\n");
        my $S2 = julia2H($s);   #FIXME slow if length($s) is large (either bc of get_local_hierarchy or YAML::load)
        # round-trip test
        $test = Dump($S) eq Dump($S2);
        print("[Optim::solve] Round-trip test: $test\n");
        print("[Optim::solve] Sleeping\n");
        sleep rand();  #TODO try random sleep
        print("[Optim::solve] Reading again\n");
        $s = join("", <$pipe_SIM>);
        $test = $s eq "DONE";
        $done = 1 if $s eq "DONE";
        print("[Optim::solve] Read '$s'.\n"); 
    }
    print("[Optim::solve] DONE. Closing pipe_SIM\n") if $done;
    close($pipe_SIM);

    print("[Optim::solve] Waiting for child\n");
    waitpid $pid, 0;

    system("rm $pname_SIM $pname_RES") == 0 or die "[Optim::solve] Could not remove pipes: $!";
    print("[Optim::solve] Exiting\n");
    return 0;
}

sub solve {
    my $P = shift;

    my $pname_SIM = "$DrCachesim::TMPDIR/pipeSIM-$$";
    my $pname_RES = "$DrCachesim::TMPDIR/pipeRES-$$";
    system("mkfifo $pname_SIM $pname_RES") == 0 or die "[Optim::solve] Could not create pipes: $!";

    print("[Optim::solve] Forking child\n");
    my $pid = fork;
    if ($pid == 0) {
        print("[Optim::solve][child] Calling exec..\n");
        my $cmd = "julia aux/optim.jl $pname_SIM $pname_RES";
        exec $cmd or die "Exec failed: $!";
    }

    my $done = 0;
    my $pipe_RES;
    my $pipe_SIM;
    my $s;  # to simulate (YAML string)
    my $S;  # to simulate (list of Perl hierarchies hash refs)
    my @R;  # simulation results (")
    my $r;  # simulation results (YAML string)

    print("[Optim::solve] Opening pipe_SIM\n");
    open($pipe_SIM, "<", $pname_SIM) or die "[Optim::solve] Could not open $pname_SIM: $!";
    
    while (not $done) {
        $s = join("", <$pipe_SIM>);  # reads until EOF
        if ($s eq "DONE"){
            $done = 1;
            @R = ();
            $r = "";
        } else {
            $S = julia2H($s);   #FIXME slow if length($s) is large (either bc of get_local_hierarchy or YAML::load)
            @R = DrCachesim::parallel_run $P, $S;
            $r = H2julia(\@R);
        }
        print("[Optim::solve] Opening pipe_RES\n");
        #Opening "normally" blocks until read pipe end is opened too (barrier)
        open($pipe_RES, ">", $pname_RES) or die "[Optim::solve] Could not open $pname_RES: $!";
        print($pipe_RES $r);
        print("[Optim::solve] Done. Closing pipe_RES\n");
        #We need to close $pipe_RES after writing, so julia's 'read' receives EOF
        close($pipe_RES);
    }

    # read final result
    $s = join("", <$pipe_SIM>);  # reads until EOF
    $S = julia2H($s);

    print("[Optim::solve] Waiting for child\n");
    waitpid $pid, 0;
    close($pipe_SIM);
    system("rm $pname_SIM $pname_RES") == 0 or die "[Optim::solve] Could not remove pipes: $!";

    return $S;
}

1;
