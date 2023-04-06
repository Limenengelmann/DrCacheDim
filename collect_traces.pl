use strict; 
use warnings;
use Data::Dumper;
use Storable qw(dclone);

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
    my $H = shift;
    #my $simcfg = shift || "/home/elimtob/Workspace/mymemtrace/config/cachesim_single.dr";
    my $simcfg = DrCachesim::create_cfg($H);
    my $exe = %$SpecInt::test_run{$k}->[0];
    SpecInt::chdir $k;
    print "Executing: $exe\n";
    #my $simt = "-simulator_type basic_counts";
    my $simt = "";
    my $cmd = qq# drrun -root "$DrCachesim::drdir" -t drcachesim -config_file $simcfg $simt -- $exe 2>&1#;
    my $ret = DrCachesim::parse_results($cmd, $H);
    die "Ret $ret. Command failed: $!.\n" unless $ret == 0;
}

#spec_instrumentation "imagick_r", "$memtrdir/lib/libbbsize.so";
#run_all();

my $H = DrCachesim::new_hierarchy();
#DrCachesim::parse_results $H;
$H->{L1I}->{cfg}->{size}  = 2**6;
$H->{L1I}->{cfg}->{assoc} = 1;
$H->{L1D}->{cfg}->{size}  = 2**16;
$H->{L1D}->{cfg}->{assoc} = 4;
$H->{L2}->{cfg}->{size}   = 2**20;
$H->{L2}->{cfg}->{assoc}  = 8;
$H->{L3}->{cfg}->{size}   = 2**30;
$H->{L3}->{cfg}->{assoc}  = 16;

spec_cachesim "imagick_r", $H;
print Dumper($H);
exit 0;
