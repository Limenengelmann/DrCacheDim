use strict; 
use warnings;
use Data::Dumper;

use lib qw#./aux#;
use SpecInt;
use DrCachesim;

my $memtrdir="/home/elimtob/Workspace/mymemtrace";
#my $dbdir="/mnt/extSSD/traces";
my $dbdir="/home/elimtob/Workspace/mymemtrace/traces";

sub collect_memrefs {
    my $r = shift;
    my $db = shift;

    my $pid = fork();
    if ($pid == 0) {
        exec("$memtrdir/build/process_memrefs $db");
    }

    my $ret = system(qq# drrun -root "$DrCachesim::drdir" -c "$memtrdir/build/libmymemtrace_x86.so" -- $r #);

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
    my $exe = %$SpecInt::test_run{$k}->[0];
    SpecInt::chdir $k;
    print "Executing: $exe\n";
    my $simcfg = "-config_file /home/elimtob/Workspace/mymemtrace/config/cachesim_single.dr";
    #my $simt = "-simulator_type basic_counts";
    my $simt = "";
    my $ret = system(qq# drrun -root "$DrCachesim::drdir" -t drcachesim $simcfg $simt-- $exe #);
    die "Ret $ret. Command failed: $!.\n" unless $ret == 0;
}

#spec_instrumentation "imagick_r", "$memtrdir/lib/libbbsize.so";
#run_all();
#spec_cachesim "imagick_r";

my $H = DrCachesim::new_hierarchy();
#DrCachesim::parse_results $H;
#print Dumper($H);
#TODO Following problem: if keys map 1to1 to drcachesim parameters, cannot add custom fields
$H->{L1} = {
    name           => "test",
    type           => "data",
    core           => 0,
    size           => 2**12,
    assoc          => 8,
    inclusive      => undef,
    parent         => "memory",
    prefetcher     => "none",
    replace_policy => "LRU",
};

DrCachesim::create_cfg $H;
exit 0;
