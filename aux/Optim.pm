package Optim;

use strict; 
use warnings;

use DrCachesim;
use YAML qw/ Load LoadFile Dump DumpFile /;

sub solve {
    my $P = shift;
    my $H = shift;
    $H =  DrCachesim::get_local_hierarchy() if not defined $H;

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

    #XXX trapping SIGINT does not work properly here unfortunately (too easy to interupt one of the many syscalls)
    #$SIG{INT} = sub { print "[Optim::solve] Caught a sigint $!"};

    my $done = 0;
    my $pipe_RES;
    my $pipe_SIM;
    my $s;  # to simulate (YAML string)
    my $S;  # to simulate (list of Perl hierarchies hash refs)
    my @R;  # simulation results (")
    my $r;  # simulation results (YAML string)

    # Send hierarchy prototype
    print("[Optim::solve] Sending H protoype\n");
    open($pipe_RES, ">", $pname_RES) or die "[Optim::solve] Could not open $pname_RES: $!";
    print($pipe_RES Dump($H));
    close($pipe_RES);

    while (not $done) {
        print("[Optim::solve] Reading pipe_SIM\n");
        open($pipe_SIM, "<", $pname_SIM) or die "[Optim::solve] Could not open $pname_SIM: $!";
        $s = join("", <$pipe_SIM>);  # reads until EOF
        close($pipe_SIM);
        if ($s eq "DONE"){
            print("[Optim::solve] Received DONE.\n");
            $done = 1;
            @R = ();
            $r = "DONE";
            print("[Optim::solve] Sending DONE to pipe_RES\n");
        } else {
            #print("[Optim::solve] Parsing '$s'\n");
            #$S = julia2H($s);   #FIXME slow if length($s) is large (either bc of get_local_hierarchy or YAML::load)
            $S = Load($s);
            print("[Optim::solve] Starting simulation.\n");
            @R = DrCachesim::parallel_run $P, $S;
            print("[Optim::solve] Serializing results.\n");
            #$r = H2julia(\@R);
            $r = Dump(\@R);
            print("[Optim::solve] Sending results to pipe_RES\n");
        }
        #Opening "normally" blocks until read pipe end is opened too (barrier)
        open($pipe_RES, ">", $pname_RES) or die "[Optim::solve] Could not open $pname_RES: $!";
        print($pipe_RES $r);
        print("[Optim::solve] Done. Closing pipe_RES\n");
        #We need to close $pipe_RES after writing, so julia's 'read' receives EOF
        close($pipe_RES);
    }

    print("[Optim::solve] Reading final results.\n");
    # read final result
    open($pipe_SIM, "<", $pname_SIM) or die "[Optim::solve] Could not open $pname_SIM: $!";
    $s = join("", <$pipe_SIM>);  # reads until EOF
    #print("[Optim::solve] Parsing results: '$s'\n");
    #$S = julia2H($s);
    $S = Load($s);

    print("[Optim::solve] Read results. Waiting for child\n");
    waitpid $pid, 0;
    close($pipe_SIM);
    system("rm $pname_SIM $pname_RES") == 0 or die "[Optim::solve] Could not remove pipes: $!";

    print("[Optim::solve] Finished.\n");
    return $S;
}

1;
