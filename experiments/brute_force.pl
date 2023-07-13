#!/usr/bin/perl
use strict; 
use warnings;

use lib "/home/elimtob/Workspace/mymemtrace/aux";
use RefGen;
use SpecInt;
use DrCachesim;
use Optim;
use Aux;

use YAML qw/ Load LoadFile Dump DumpFile /;
use List::Util qw( sample );

my $Hmin = DrCachesim::get_local_hierarchy();
my $Hmax = DrCachesim::get_local_hierarchy();


# "open" bounds
DrCachesim::set_sets_ways($Hmin, (64, 8, 32, 1, 64, 1, 128, 1));
DrCachesim::set_sets_ways($Hmax, (64, 8, 1024, 16, 8192, 16, 2**15, 16));

my $hcube_sweep = DrCachesim::cube_sweep($Hmin, $Hmax);
my $cap = 512;
@$hcube_sweep = sample $cap, @$hcube_sweep;

my $cost_scale = 1; #0.00001
my @cost = map {$cost_scale * $_} @DrCachesim::DEFAULT_COST_RATIO;


my $name = "matmul_ref";
my $n = 64;
#my $name = "imagick_r";
#my $name = "x264_r";    # 210s per sim (or 1 min/sim multithreaded)
#my $name = "mcf_r";
#my $name = "xz_r";
my $tstamp = Aux::get_tstamp();
my $resf = "$Aux::RESDIR/$name-brutef-$tstamp.yml";


#TODO analyse locality via reuse distance

my $P = DrCachesim::default_problem("$Aux::ROOT/bin/$name $n");
# crashes x264_r when using this
#my $drargs = "";
#my $drargs = $Aux::HEAD_ONLY_SIM;
#$P->{exe} = SpecInt::testrun_callback($name, $drargs);
$P->{cost} = DrCachesim::get_real_cost_fun(\@cost);

@$hcube_sweep = DrCachesim::parallel_run $P, $hcube_sweep;

DumpFile($resf, $hcube_sweep);
Aux::notify_when_done("$resf is done!");
printf "Wrote results to '$resf'\n";
