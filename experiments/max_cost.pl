#!/usr/bin/perl
use strict; 
use warnings;


use lib "/home/elimtob/Workspace/drcachedim/aux";
use RefGen;
use SpecInt;
use DrCacheDim;
use Optim;
use Aux;

use YAML qw/ Load LoadFile Dump DumpFile /;

my $H0 = DrCacheDim::get_local_hierarchy();
my $Hmin = DrCacheDim::get_local_hierarchy();
my $Hmax = DrCacheDim::get_local_hierarchy();

# "realistic" bounds from ./aux/cache-db
DrCacheDim::set_sets_ways($Hmin, (64, 8, 64, 2, 512, 4, 2048, 8));
DrCacheDim::set_sets_ways($Hmax, (64, 8, 512, 16, 1024, 20, 8192, 64));

# "open" bounds
#DrCacheDim::set_sets_ways($Hmin, (32, 1, 32, 1, 64, 1, 128, 1));
#DrCacheDim::set_sets_ways($Hmax, (512, 16, 1024, 16, 8192, 16, 2**15, 16));

my $cost_scale = 1; #0.00001
my @cost = map {$cost_scale * $_} @DynamoRIO::DEFAULT_COST_RATIO;

my $name = "imagick_r";
#my $name = "x264_r";    # 210s per sim (or 1 min/sim multithreaded)
#my $name = "mcf_r";
#my $name = "xz_r";
my $max_cost = 4144497;
my $tstamp = Aux::get_tstamp();
my $resf = "$Aux::RESDIR/$name-max_cost-$max_cost-$tstamp.yml";
my $jcfg = "$Aux::ROOT/experiments/max_cost.jl";

my $P = DrCacheDim::default_problem();

# x264_r crashes when using sampling
#my $drargs = "-warmup_refs 10000 -retrace_every_instrs 800000 -trace_for_instrs 200000";
my $drargs = "";
$P->{exe} = SpecInt::testrun_callback($name, $drargs);
$P->{cost} = DrCacheDim::get_real_cost_fun(\@cost);
$P->{val} = sub { my $H = shift; return $H->{COST} > $max_cost ? $Aux::BIG_VAL : $H->{MAT}; };
$P->{jcfg} = "$jcfg";

#DrCacheDim::run_cachesim($P, $H0);

my $tic = time();
my $res = Optim::solve(P => $P, H0 =>$H0, Hmin => $Hmin, Hmax => $Hmax);
my $toc = time() - $tic;
printf "Finished in %.2f s or %.2f m or %.2f h\n", $toc, $toc / 60 , $toc / 3600;

DumpFile($resf, $res);
Aux::notify_when_done("$resf is done!");
printf "Wrote results to '$resf'\n";
