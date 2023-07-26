#!/usr/bin/perl
use strict; 
use warnings;
use lib qw#./aux#;
use RefGen;
use SpecInt;
use DrCacheDim;
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

    my $ret = system(qq# drrun -root "$DrCacheDim::DRDIR" -c "$CWD/lib/libmymemtrace_x86.so" $drargs -- $cmd #);

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

    my $H = DrCacheDim::get_local_hierarchy();
    #check_fetch_latency
    #XXX: only number of sets per way needs to be power of 2
    #$H->{L1D}->{cfg}->{assoc} = $H->{L1D}->{cfg}->{size} / 64;  # fully associative
    #$H->{L3}->{cfg}->{size} = 2**30;

    #XXX outdated
    my $s1I = DrCacheDim::brutef_sweep(H => $H, L1I => [13,17,1,4]);
    my $s1D = DrCacheDim::brutef_sweep(H => $H, L1D => [13,17,1,4]);
    my $s2  = DrCacheDim::brutef_sweep(H => $H, L2  => [19,23,1,4]);
    my $s3  = DrCacheDim::brutef_sweep(H => $H, L3  => [21,25,1,4]);
    my $level_sweep = [
        @$s1I, 
        @$s1D,
        @$s2,
        @$s3,
    ];

    my $hcube_sweep = DrCacheDim::brutef_sweep(H => $H, L1I => [10,11,1,3], 
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
    $sweep = DrCacheDim::brutef_sweep(H => $H, L1I  => [15,15,0,4]);
    #print Dump($$sweep[0]);

    my $rfile = DrCacheDim::parallel_run $P, $sweep;

    my @tstamp = reverse localtime;
    $tstamp[-5]++;
    my $tstamp= join("-", @tstamp[-5 .. -1]);

    move "$rfile", "$CWD/results/${name}_$tstamp.yml";
    print Dump($sweep);
    DrCacheDim::beep_when_done();
}

################################################ main ###################################################

my $H = DrCacheDim::get_local_hierarchy();
my @cost1 = (1, 1, 1, 1, 1, 1, 1, 1);
my @cost2 = (10000, 10000, 10000, 10000, 10000, 10000, 10000, 10000);
my @cost3 = (0.01) x 8;
my @cost4 = map {0.001 * $_} reverse((1..8));
my @cost5 = (1, 1, 1, 1, 0.1, 0.1, 0.01, 0.01);
my @cost6 = map {0.01 * $_} @cost5;
my $H0 = DrCacheDim::get_local_hierarchy();

# just testing costs
# relative cost per bit = **-0.6 latency
#printf("%f\n%f\n%f\n%f\n", $H->{L1I}->{lat}**-0.6,
#                           $H->{L1D}->{lat}**-0.6,   
#                           $H->{L2}->{lat} **-0.6,     
#                           $H->{L3}->{lat} **-0.6);

my $name1; 
$name1 = "mcf_r";
$name1 = "x264_r";
$name1 = "xz_r";
$name1 = "perlbench_r";
$name1 = "xalancbmk_r";
$name1 = "omnetpp_r";
$name1 = "imagick_r";

my $P1 = DrCacheDim::default_problem();
$P1->{exe} = SpecInt::testrun_callback($name1);
$P1->{cost} = DrCacheDim::get_real_cost_fun(\@cost5);
#$P1->{cost} = DrCacheDim::get_real_cost_fun(\@cost4);

#
#bruteforce_sim($P2, $name2);
#cache, miss_analyzer, TLB, histogram, reuse_distance, basic_counts, opcode_mix, view or func_view
#DrCacheDim::run_analysistool($x1, "-simulator_type reuse_distance -reuse_distance_histogram -reuse_histogram_bin_multiplier 1.05");
#DrCacheDim::run_analysistool($x1, "-simulator_type reuse_distance -reuse_distance_threshold 1");
#DrCacheDim::update_simulations "./results";
#my $dbname = 
#collect_memrefs($x, "./tracer/traces/$name-1.db");

#my $S = LoadFile("results/imagick_r_level.yml");
#print Dump(DrCacheDim::get_best($S));
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


#my @h_opt = (64, 8, 64, 16, 1024, 16, 16384, 8);   # local size rounded to powers of 2
#DrCacheDim::set_sets_ways($H, @h_opt);
#my $h0 = (@$h_opt);   # local size
my $fn = RefGen::capway_code($H);
$fn = RefGen::compile_code $fn;

my $P3 = DrCacheDim::default_problem($fn);
#DrCacheDim::run_analysistool($P3, "-simulator_type basic_counts");
#DrCacheDim::run_cachesim($P3, $H);
#bruteforce_sim($P3, basename($fn));
#DrCacheDim::run_analysistool($P3, "-simulator_type histogram");
#DrCacheDim::run_analysistool($P3, "-simulator_type reuse_distance -reuse_distance_histogram -reuse_distance_threshold 0");

#system("cat $fn");
#Optim::comm_test($P3) == 0 or die "Optim::comm_test failed!";
$P3->{cost} = DrCacheDim::get_lin_cost_fun(\@cost4);
$P3->{cost} = DrCacheDim::get_real_cost_fun(\@cost5);
$P3->{cost} = DrCacheDim::get_real_cost_fun(\@cost6);
#$P3->{val} = DrCacheDim::get_max_lat_val(34630732);

#$H0->{L1I}->{cfg}->{size} /= 2;
#$H0->{L1I}->{cfg}->{assoc} = 2;
#$H0->{L1D}->{cfg}->{size} /= 2;
#$H0->{L1D}->{cfg}->{assoc} = 3;
#$H0->{L2}->{cfg}->{assoc} = 16;
#$H0->{L2}->{cfg}->{size} = 32 * $H0->{L2}->{cfg}->{assoc}*64;
#$H0->{L3}->{cfg}->{size} *= 4;
#$H0->{L3}->{cfg}->{assoc} = 4;

#DrCacheDim::set_sets_ways($H0, (64, 8, 128, 12, 1024, 20, 4096, 64));
#DrCacheDim::set_sets_ways($H0, (64, 8, 512, 7, 1024, 20, 4096, 51));
#DrCacheDim::set_sets_ways($H0, (64, 8, 64, 12, 1024, 20, 16384, 8));   # local size
#DrCacheDim::set_sets_ways($H0, (64, 8, 64, 12, 1024, 20, 16384/8, 8));
#DrCacheDim::set_sets_ways($H0, (64, 8, 64, 16, 1024, 16, 16384*2, 8));
#DrCacheDim::set_sets_ways($H0, (64, 8, 64, 16, 512, 4, 2048, 9)); # theoretical minimum
#DrCacheDim::set_sets_ways($H0, (64, 8, 64, 16, 1024, 20, 4096, 32));
#DrCacheDim::set_sets_ways($H0, (64, 8, 64, 16, 1024, 17, 4096, 32));
#DrCacheDim::set_sets_ways($H0, (64, 8, 64, 16, 1024, 16, 4096, 32));
#DrCacheDim::set_sets_ways($H0, (64, 8, 512, 7, 1024, 20, 16384, 12));
#DrCacheDim::set_sets_ways($H0, (64, 8, 512, 7, 2048, 3, 16384, 15));
#DrCacheDim::set_sets_ways($H0, (64, 8, 128, 64, 512, 64, 2048, 64));
#DrCacheDim::set_sets_ways($H0, (64, 8, 512, 16, 512, 16, 16384, 32));

# Simulate optimum and start value for better overview afterwards
#($H, $H0) = DrCacheDim::parallel_run($P3, [$H, $H0]);
($H, $H0) = DrCacheDim::parallel_run($P1, [$H, $H0]);
#print(Dump($H));
#print(Dump($H0));

print("Start hierarchy:\n");
DrCacheDim::print_hierarchy($H0);

my $res3;
$res3 = Optim::solve($P1, $H0);
#print(Dump($res3));
my $len3 = @$res3;
my $opt3 = $res3->[-1];
print("[main] Length result: $len3\n");
print("[main] Solved: $fn\n");
print("[main] Start value\n");
DrCacheDim::print_hierarchy($H0);
print("[main] Found solution:\n");
DrCacheDim::print_hierarchy($opt3);
print("[main] Theoretical Optimum: $fn\n");
DrCacheDim::print_hierarchy($H);
# TODO Result file name
#my $out3 = "";
#DumpFile($rfile, $sweep) or die "parallel_sweep: Can't load tmp results: $!";
#  64  8  256  2  1024  4  2048  8 |    516423  11277206  11793630
#  64  8   64  2   512  4  2048  8 |    414842   2682846   3097689


exit 0;
