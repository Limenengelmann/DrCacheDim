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

    print "Successfull cmds: $succ. Failed cmds: " . scalar(@failed). ".\n@failed\n";
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
    my $exe = %$SpecInt::test_run{$k}->[0];
    SpecInt::chdir $k;
    my $cmd = qq# drrun -root "$DrCachesim::drdir"       
                        -t drcachesim                    
                        -ipc_name /tmp/drcachesim_pipe$$ 
                        -config_file $simcfg             
                        -- $exe#;
    # remove newlines and unnecessary whitespaces in command
    $cmd = $cmd =~ s/\n/ /gr =~ s/  +/ /gr;
    print "Executing: $cmd\n";
    my $ret = DrCachesim::run_and_parse_output($cmd, $H);
    die "Ret $ret. Command failed: $!.\n" unless $ret == 0;
}

#spec_instrumentation "imagick_r", "$CWD/lib/libbbsize.so";
#run_all();

my $x = "imagick_r";
#                                    L1I    L1D    L2       L3
my $sweep = DrCachesim::brutef_sweep((7,7), (9,9), (14,14), (20,20), 
                                     (1,1), (0,3), (3,3),   (3,3));
#TODO limit number of forks, maybe predetermine it and split $sweep accordingly using slices
my @pids = ();
foreach my $H (@$sweep) {
    my $pid = fork;
    if ($pid == 0) {
        print "$$: Hello!\n";
        print Dumper($H);
        spec_cachesim $x, $H;

        #NOTE list context for $fh so file is not auto-deleted
        my ($fh) = tempfile("${x}_sim_XXXXXXX", DIR => "$CWD/results");
        print $fh Dumper($H);
        exit 0;
    }
    push @pids, $pid;
}
wait for @pids;

exit 0;
