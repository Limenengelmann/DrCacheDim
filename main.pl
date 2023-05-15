use strict; 
use warnings;
use lib qw#./aux#;
use SpecInt;
use DrCachesim;

use Data::Dumper;
use Storable qw(dclone);
use File::Temp qw/ tempfile /;
use File::Copy qw/ move /;
use YAML qw/ Load LoadFile Dump DumpFile /;
use List::Util qw( sample none );
use Time::HiRes qw( time );
use IO::Handle;

my $CWD="/home/elimtob/Workspace/mymemtrace";
#my $dbdir="/mnt/extSSD/traces";
my $dbdir="/home/elimtob/Workspace/mymemtrace/traces";

sub collect_memrefs {
    my $x = shift;
    my $db = shift;
    
    my ($cmd, $drargs) = &$x();

    my $pid = fork();
    if ($pid == 0) {
        exec("$CWD/bin/process_memrefs $db");
    }

    my $ret = system(qq# drrun -root "$DrCachesim::DRDIR" -c "$CWD/lib/libmymemtrace_x86.so" $drargs -- $cmd #);

    waitpid $pid, 0;
    
    #if ($ret == 0) {
    #    waitpid $pid, 0;
    #} else {
    #    print "Ret $ret. Command failed: $!.\n";
    #    kill "SIGINT", $pid;
    #}
    return $ret;
}

sub run_all {
    # create traces!
    print("-----------------------------------------------------------------------------------------------------------------\n");
    print("-----------------------------------------------------------------------------------------------------------------\n");

    die "$dbdir does not exist! Aborting.\n" unless (-d "$dbdir");

    my @failed=();
    my $succ=0;
    while (my ($k, $v) = each(%$SpecInt::test_run)) {
        SpecInt::chdir $k;
        print "\nExecuting benchmark cmds for $k\n";
        foreach my $r (@$v) {
            #$r = "echo 'blabla'";  # for testing
            #TODO don't run twice just to get the exit value
            if (system($r) == 0) {
                $succ++;
                collect_memrefs($r, "$dbdir/$k-$SpecInt::size.db");
            } else {
                push @failed, ($r, $!);
            }
        }
    }

    print "Successfull cmds: $succ. Failed cmds: " . scalar(@failed) . ".\n@failed\n";
}

sub spec_instrumentation {
    my $k = shift;
    my $client = shift;
    my $exe = %$SpecInt::test_run{$k}->[0];

    SpecInt::chdir $k;
    print "Executing: $exe\n";
    my $ret = system(qq# drrun -root "$DrCachesim::DRDIR" -c "$client" -- $exe #);
    die "Ret $ret. Command failed: $!.\n" unless $ret == 0;
}

sub run_cachesim {
    #my $k = shift;
    my $cb = shift;
    my $H = shift;
    #my $simcfg = shift || "/home/elimtob/Workspace/mymemtrace/config/cachesim_single.dr";
    my $simcfg = DrCachesim::create_cfg($H);
    #TODO run all parts instead
    #my $exe = %$SpecInt::test_run{$k}->[0];
    my ($exe, $drargs) = &$cb();
    #SpecInt::chdir $k;
    my $cmd = DrCachesim::drrun_cachesim($simcfg, $exe, $drargs);
    #print "Executing: $cmd\n";
    #print "Before: " . Dumper($H);
    #my $ret = DrCachesim::run_and_parse_output($cmd, $H);
    my ($ret, $cmdout) = DrCachesim::run_and_parse_output($cmd, $H, $drargs); #print $cmdout;
    #print "After: " . Dumper($H);
    if ($ret != 0) {
        my $msg = "[run_cachesim#$$]: run and parse returned $ret. Command failed: $!";
        my $h = Dump($H);
        die "$msg\nCommand output: $cmdout\nCommand: $cmd\nConfig:$h\n";
    }
}

sub parallel_sweep {
    my $cb     = shift;
    my $sweep = shift;
    my $procs = shift || `nproc --all`;
    chomp $procs;

    my $len = @$sweep;
    $procs = $len if $len < $procs;
    my $share = $len / $procs;

    print "parallel_sweep with $procs procs and $len configs\n";

    pipe(my $reader, my $writer);

    #TODO trap SIGINT for graceful shutdown
    #TODO estimate time left
    #TODO measure simulation speed
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
                print "";
                run_cachesim $cb, $H;
                DrCachesim::set_amat $H;
                #print Dump($H);
                print $writer "\n";
            }
            #FIXME strips object type
            #XXX: Does that really matter? Maybe for loading, but even then maybe scrap OO completely
            DumpFile("/tmp/drcachesim_$$.yml", \@slice) or die "parallel_sweep: Can't open file: $!";
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
        my $toc = time();
        my $sim_speed = $count / ($toc-$tic);
        $time_left = ($len-$count) / $sim_speed if $sim_speed > 0;
        printf "%d/%d simulations done in %.1fs, %.1fs left (%.1f sims/s)\r", $count, $len, $toc-$tic, $time_left, $sim_speed;
        STDOUT->flush();
        $count++;
    } while (my $c = <$reader>);
    print "\n";

    @$sweep = ();   # empty the sweep
    foreach my $p (@pids) {
        waitpid $p, 0;
        my $fname = "/tmp/drcachesim_$p.yml";
        die "parallel_sweep: Error in process $p: Missing output file '$fname'. Aborting" unless -e $fname;
        #my $s = `cat /tmp/${x}_sim_$p`;
        #$s = eval "my " . $s or die "eval failed: $@";
        my $s = LoadFile($fname) or die "parallel_sweep: Can't load tmp results: $!";
        push @$sweep, @$s;
        `rm $fname`;
    }
    # collect results and store in results
    my $rfile = "$CWD/results/drcachesim_$$.yml";
    DumpFile($rfile, $sweep) or die "parallel_sweep: Can't load tmp results: $!";
    return $rfile;
}

sub run_simulation {
    my $x = shift;
    my $name = shift;
    #spec_instrumentation "imagick_r", "$CWD/lib/libbbsize.so";
    #run_all();
    #parallel_sweep $x, $sweep;

    #check_fetch_latency
    #XXX: only number of sets per way needs to be power of 2
    my $H = DrCachesim::get_local_hierarchy();

    my $s1I = DrCachesim::brutef_sweep(H => $H, L1I => [15,15,1,3]);
    my $s1D = DrCachesim::brutef_sweep(H => $H, L1D => [16,17,1,3]);
    my $s2  = DrCachesim::brutef_sweep(H => $H, L2  => [21,23,1,4]);
    my $s3  = DrCachesim::brutef_sweep(H => $H, L3  => [23,25,1,4]);
    my $level_sweep = [
        @$s1I, 
        @$s1D,
        @$s2,
        @$s3,
    ];

    my $hcube_sweep = DrCachesim::brutef_sweep(H => $H, L1I => [10,11,1,3], 
                                                       L1D => [10,13,1,3],
                                                       L2  => [14,17,1,3],
                                                       L3  => [18,20,1,3]);

    my $sweep = $hcube_sweep;

    my $cap = 1;
    print "Limiting sweep to $cap simulation\n";
    @$sweep = sample $cap, @$sweep;
    #push @$sweep, $H;
    #$H->{L1D}->{cfg}->{assoc} = 8;
    $H->{L1D}->{cfg}->{size} >>= 5;
    #$H->{L2}->{cfg}->{assoc} = 8;
    #$H->{L2}->{cfg}->{size} = 2 << 15;
    #$H->{L3}->{cfg}->{assoc} = 8;
    #$H->{L3}->{cfg}->{size} = 2 << 19;
    @$sweep = ($H);
    #print Dump($$sweep[0]);

    my $rfile = parallel_sweep $x, $sweep;

    my @tstamp = reverse localtime;
    $tstamp[-5]++;
    my $tstamp= join("-", @tstamp[-5 .. -1]);

    move "$rfile", "$CWD/results/${name}_$tstamp.yml";
    #print Dumper($$sweep[0]);
    print Dump($$sweep[0]->{L1D});
    print Dump($$sweep[0]->{cmd});
    #print Dump($$sweep[0]->{L1D}->{stats});
    #print Dump($$sweep[0]);
    #DrCachesim::beep_when_done();
}

my $name = "imagick_r";
my $x = SpecInt::testrun_dispatcher($name);

$name = "cachetest";
$x = sub {
    my $H = DrCachesim::get_local_hierarchy();
    my $s1 = $H->{L1D}->{cfg}->{size}*2;
    $s1 = 98304;
    my $r1 = $s1*5/64;
    $r1 = 100000;

    my $s2 = $H->{L2}->{cfg}->{size};
    my $r2 = 1;

    my $s3 = $H->{L3}->{cfg}->{size};
    my $r3 = 1;

    my $cmd = sprintf "$CWD/bin/$name %d %d %d %d %d %d", $s1, $r1, $s2, $r2, $s3, $r3;
    my $drargs = join(" ", 
        #"-skip_refs 5000000",
        #"-simulator_type basic_counts",
    );

    return ($cmd, $drargs);
};

#run_simulation($x, $name);
#DrCachesim::update_simulations "./results";
my $dbname = 
collect_memrefs($x, "./tracer/traces/$name-1.db");

exit 0;
