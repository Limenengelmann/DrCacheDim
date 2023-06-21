#!/usr/bin/perl
use strict; 
use warnings;
use lib qw#./aux#;
use RefGen;
use SpecInt;
use DrCachesim;
use Optim;

use Data::Dumper;
use Storable qw(dclone);
use File::Temp qw/ tempfile /;
use File::Basename;
use File::Copy qw/ move /;
use YAML qw/ Load LoadFile Dump DumpFile /;
use List::Util qw( sample none );
use Time::HiRes qw( time );
use IO::Handle;

my $CWD="/home/elimtob/Workspace/mymemtrace";
#my $dbdir="/mnt/extSSD/traces";
my $dbdir="/home/elimtob/Workspace/mymemtrace/traces";

sub collect_memrefs {
    my $P = shift;
    my $db = shift;
    
    my ($cmd, $drargs) = $P->{exe}->();

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

sub bruteforce_sim {
    my $P = shift;
    my $name = shift;

    my $H = DrCachesim::get_local_hierarchy();
    #check_fetch_latency
    #XXX: only number of sets per way needs to be power of 2
    #$H->{L1D}->{cfg}->{assoc} = $H->{L1D}->{cfg}->{size} / 64;  # fully associative
    #$H->{L3}->{cfg}->{size} = 2**30;

    my $s1I = DrCachesim::brutef_sweep(H => $H, L1I => [13,17,1,4]);
    my $s1D = DrCachesim::brutef_sweep(H => $H, L1D => [13,17,1,4]);
    my $s2  = DrCachesim::brutef_sweep(H => $H, L2  => [19,23,1,4]);
    my $s3  = DrCachesim::brutef_sweep(H => $H, L3  => [21,25,1,4]);
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
    #$sweep = $level_sweep;

    my $cap = 1000;
    print "Limiting sweep to $cap simulation\n";
    @$sweep = sample $cap, @$sweep;
    push @$sweep, $H;
    #$H->{L1D}->{cfg}->{assoc} = 8;
    #$H->{L1D}->{cfg}->{size} >>= 5;
    #$H->{L2}->{cfg}->{assoc} = 8;
    #$H->{L2}->{cfg}->{size} = 2 << 15;
    #$H->{L3}->{cfg}->{assoc} = 8;
    #$H->{L3}->{cfg}->{size} = 2 << 19;
    #$H->{L3}->{cfg}->{size} = $H->{L3}->{cfg}->{size} / 2;
    #$H->{L1I}->{cfg}->{assoc} = 2;
    #$H->{L1I}->{cfg}->{size} = 2*2*64;
    #$H->{L1D}->{cfg}->{assoc} = 2;
    #$H->{L1D}->{cfg}->{size} = 2*2*64;
    #@$sweep = ($H);
    $sweep = DrCachesim::brutef_sweep(H => $H, L1I  => [15,15,0,4]);
    #print Dump($$sweep[0]);

    my $rfile = DrCachesim::parallel_run $P, $sweep;

    my @tstamp = reverse localtime;
    $tstamp[-5]++;
    my $tstamp= join("-", @tstamp[-5 .. -1]);

    move "$rfile", "$CWD/results/${name}_$tstamp.yml";
    print Dump($sweep);
    DrCachesim::beep_when_done();
}

################################################ main ###################################################

my $H = DrCachesim::get_local_hierarchy();

# just testing costs
# relative cost per bit = **-0.6 latency
#printf("%f\n%f\n%f\n%f\n", $H->{L1I}->{lat}**-0.6,
#                           $H->{L1D}->{lat}**-0.6,   
#                           $H->{L2}->{lat} **-0.6,     
#                           $H->{L3}->{lat} **-0.6);

my $name1 = "imagick_r";
my $P1 = DrCachesim::default_problem();
$P1->{exe} = SpecInt::testrun_callback($name1);

my $name2 = "cachetest";
my $P2 = DrCachesim::default_problem();
$P2->{exe} = sub {
        my $s1 = $H->{L1D}->{cfg}->{size};
        my $r1 = $s1*5/64;
        $r1 = 1000000;

        my $s2 = $H->{L2}->{cfg}->{size};
        my $r2 = 1;

        my $s3 = $H->{L3}->{cfg}->{size};
        my $r3 = 1;

        my $cmd = sprintf "$CWD/bin/$name2 %d %d %d %d %d %d", $s1, $r1, $s2, $r2, $s3, $r3;
        my $drargs = join(" ", 
            #"-skip_refs 5000000",
            #"-simulator_type basic_counts",
        );

        return ($cmd, $drargs);
};

#
#bruteforce_sim($P2, $name2);
#cache, miss_analyzer, TLB, histogram, reuse_distance, basic_counts, opcode_mix, view or func_view
#DrCachesim::run_analysistool($x1, "-simulator_type reuse_distance -reuse_distance_histogram -reuse_histogram_bin_multiplier 1.05");
#DrCachesim::run_analysistool($x1, "-simulator_type reuse_distance -reuse_distance_threshold 1");
#DrCachesim::update_simulations "./results";
#my $dbname = 
#collect_memrefs($x, "./tracer/traces/$name-1.db");

#my $S = LoadFile("results/imagick_r_level.yml");
#print Dump(DrCachesim::get_best($S));
#my $fn = RefGen::generate_code 2<<7, 1e6, 2<<9, 1, 2<<10, 1;
#my $fn = RefGen::generate_code($H->{L1D}->{cfg}->{size}, 1e3,
#                               $H->{L2}->{cfg}->{size}, 1,
#                               $H->{L3}->{cfg}->{size}, 1);

#$fn = RefGen::optimal_code($H->{L1D}->{cfg}->{size},
#                           $H->{L2}->{cfg}->{size},
#                           $H->{L3}->{cfg}->{size});

my $r23 = $H->{L2}->{cfg}->{size} / $H->{L3}->{cfg}->{size};
my $r12 = ($H->{L1D}->{cfg}->{size} + $H->{L1I}->{cfg}->{size}) / $H->{L2}->{cfg}->{size};

printf("[Local Ratios] r12: %.2e, r23: %.2e\n", $r12, $r23);

#$H->{L1I}->{cfg}->{assoc} = 2;
#$H->{L1I}->{cfg}->{size} = 2*2*64;
#$H->{L1D}->{cfg}->{assoc} = 2;
#$H->{L1D}->{cfg}->{size} = 2*2*64;

printf("local L3: assoc: %d, sets: %d. Total sets: %d\n", $H->{L3}->{cfg}->{assoc}, $H->{L3}->{cfg}->{size} / $H->{L3}->{cfg}->{assoc} / 64, $H->{L3}->{cfg}->{size} / 64);
printf("local L1I: assoc: %d, sets: %d. Total sets: %d\n", $H->{L1I}->{cfg}->{assoc}, $H->{L1I}->{cfg}->{size} / $H->{L1I}->{cfg}->{assoc} / 64, $H->{L1I}->{cfg}->{size} / 64);
printf("local L1D: assoc: %d, sets: %d. Total sets: %d\n", $H->{L1D}->{cfg}->{assoc}, $H->{L1D}->{cfg}->{size} / $H->{L1D}->{cfg}->{assoc} / 64, $H->{L1D}->{cfg}->{size} / 64);

my $fn = RefGen::capway_code($H);
$fn = RefGen::compile_code $fn;

my $P3 = DrCachesim::default_problem($fn);
#DrCachesim::run_analysistool($P3, "-simulator_type basic_counts");
#bruteforce_sim($P3, basename($fn));
#DrCachesim::run_analysistool($P3, "-simulator_type histogram");
#DrCachesim::run_analysistool($P3, "-simulator_type reuse_distance -reuse_distance_histogram -reuse_distance_threshold 0");

#system("cat $fn");
Optim::solve($P3);

exit 0;
