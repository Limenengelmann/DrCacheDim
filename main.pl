use strict; 
use warnings;
use Data::Dumper;
use Storable qw(dclone);
use File::Temp qw/ tempfile /;

use lib qw#./aux#;
use SpecInt;
use DrCachesim;

my $CWD="/home/elimtob/Workspace/mymemtrace";
#my $dbdir="/mnt/extSSD/traces";
my $dbdir="/home/elimtob/Workspace/mymemtrace/traces";

sub collect_memrefs {
    my $r = shift;
    my $db = shift;

    my $pid = fork();
    if ($pid == 0) {
        exec("$CWD/build/process_memrefs $db");
    }

    my $ret = system(qq# drrun -root "$DrCachesim::drdir" -c "$CWD/build/libmymemtrace_x86.so" -- $r #);

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
    my $ret = system(qq# drrun -root "$DrCachesim::drdir" -c "$client" -- $exe #);
    die "Ret $ret. Command failed: $!.\n" unless $ret == 0;
}

sub spec_cachesim {
    my $k = shift;
    my $H = shift;
    #my $simcfg = shift || "/home/elimtob/Workspace/mymemtrace/config/cachesim_single.dr";
    my $simcfg = DrCachesim::create_cfg($H);
    #TODO run all parts instead
    my $exe = %$SpecInt::test_run{$k}->[0];
    SpecInt::chdir $k;
    my $cmd = DrCachesim::drrun_cachesim($simcfg, $exe);
    print "Executing: $cmd\n";
    #print "Before: " . Dumper($H);
    my $ret = DrCachesim::run_and_parse_output($cmd, $H);
    #my ($ret, $cmdout) = DrCachesim::run_and_parse_output($cmd, $H); print $cmdout;
    #print "After: " . Dumper($H);
    die "Ret $ret. Command failed: $!.\n" if $ret != 0;
}

sub parallel_sweep {
    my $x     = shift;
    my $sweep = shift;
    my $procs = shift || `nproc --all`;
    chomp $procs;

    my $len = @$sweep;
    $procs = $len if $len < $procs;
    my $share = $len / $procs;

    print "parallel_sweep with $procs procs and $len configs\n";

    my @pids = ();
    for(my $p=0; $p<$procs; $p++){
        my ($b1, $b2) = ($p*$share, ($p+1)*$share -1);
        my @slice = @$sweep[$b1 .. $b2];
        my $slen = @slice;
        #print "proc $p: Share from $b1 to $b2 (length slice: $slen, slice: $s)\n";
        my $pid = fork;
        if ($pid == 0) {
            foreach my $H (@slice) {
                print "$$: Hello!\n";
                spec_cachesim $x, $H;
                DrCachesim::set_amat $H;
                #print Dumper($H);
            }
            open(my $fh, ">", "/tmp/${x}_sim_$$") or die "parallel_sweep: Can't open file: $!";
            print $fh Dumper(\@slice);
            exit 0;
        }
        push @pids, $pid;
    }

    #TODO check if previous refs are also updated
    @$sweep = ();
    #wait for @pids;
    foreach my $p (@pids) {
        waitpid $p, 0;
        my $fname = "/tmp/${x}_sim_$p";
        die "parallel_sweep: Error in process $p: Missing output file '$fname'. Aborting" unless -e $fname;
        my $s = `cat /tmp/${x}_sim_$p`;
        $s = eval "my " . $s or die "eval failed: $@";
        push @$sweep, @$s;   #TODO @$s
        `rm $fname`;
    }
    # collect results and store in results
    # TODO store as yaml for further processing
    #NOTE list context for $fh so file is not auto-deleted
    my ($fh) = tempfile("${x}_sim_XXXX", DIR => "$CWD/results");
    print $fh Dumper($sweep);
}

#spec_instrumentation "imagick_r", "$CWD/lib/libbbsize.so";
#run_all();
#parallel_sweep $x, $sweep;

#check_fetch_latency
my $H = DrCachesim::get_local_hierarchy();
my $sweep = DrCachesim::brutef_sweep(H => $H,
                                     L1I => [7,7,1,1],
                                     L1D => [9,9,3,3],
                                     L2  => [14,14,3,3],
                                     L3  => [20,20,3,3]);

my $x = "imagick_r";
parallel_sweep $x, $sweep, 2;
#print Dumper($$sweep[0]);
DrCachesim::beep_when_done();

exit 0;
