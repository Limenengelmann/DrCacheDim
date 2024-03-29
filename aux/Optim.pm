package Optim;

use strict; 
use warnings;

use DrCacheDim;
use Aux;
use YAML qw/ Load LoadFile Dump DumpFile /;

sub solve {
    my %args = @_;
    my $P = $args{P} || die "No problem passed!";
    my $H0 = $args{H0};
    $H0 =  DrCacheDim::get_local_hierarchy() if not defined $H0;
    my $Hmin = $args{Hmin} || die "No lower bound passed!";
    my $Hmax = $args{Hmax} || die "No upper bound passed!";
    my $Hopt = $args{Hopt}; # for debugging, optional

    my $Start = [$Hmin, $Hmax, $H0];
    push @$Start, $Hopt if defined $Hopt;

    my $pname_SIM = "$Aux::TMPDIR/pipeSIM-$$";
    my $pname_RES = "$Aux::TMPDIR/pipeRES-$$";
    system("mkfifo $pname_SIM $pname_RES") == 0 or die "[Optim::solve] Could not create pipes: $!";

    print("[Optim::solve] Forking child\n");
    my $pid = fork;
    if ($pid == 0) {
        print("[Optim::solve][child] Calling exec..\n");
        my $cmd = "julia $Aux::ROOT/aux/optim.jl $pname_SIM $pname_RES $P->{jcfg}";
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
    print("[Optim::solve] Sending starting problem\n");
    open($pipe_RES, ">", $pname_RES) or die "[Optim::solve] Could not open $pname_RES: $!";
    print($pipe_RES Dump($Start));
    close($pipe_RES);

    while (not $done) {
        #print("[Optim::solve] Reading pipe_SIM\n");
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
            #print("[Optim::solve] Starting simulation.\n");
            @R = DrCacheDim::parallel_run $P, $S;
            #print("[Optim::solve] Serializing results.\n");
            #$r = H2julia(\@R);
            $r = Dump(\@R);
            #print("[Optim::solve] Sending results to pipe_RES\n");
        }
        #Opening "normally" blocks until read pipe end is opened too (barrier)
        my $len = length($r);
        #print("[Optim::solve] Sending $len bytes:\n$r\n");
        open($pipe_RES, ">", $pname_RES) or die "[Optim::solve] Could not open $pname_RES: $!";
        print($pipe_RES $r) or die "[Optim::solve] Could not write to pipe_RES!";
        #print("[Optim::solve] Done. Closing pipe_RES\n");
        #We need to close $pipe_RES after writing, so julia's 'read' receives EOF
        #sleep 1;
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
