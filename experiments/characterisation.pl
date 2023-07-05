#!/usr/bin/perl
use strict; 
use warnings;


use lib "/home/elimtob/Workspace/mymemtrace/aux";
use RefGen;
use SpecInt;
use DrCachesim;
use Optim;

use YAML qw/ Load LoadFile Dump DumpFile /;

my $H0 = DrCachesim::get_local_hierarchy();
my $Hmin = DrCachesim::get_local_hierarchy();
my $Hmax = DrCachesim::get_local_hierarchy();

# "realistic" bounds from ./aux/cache-db
DrCachesim::set_sets_ways($Hmin, (64, 8, 64, 2, 512, 4, 2048, 8));
DrCachesim::set_sets_ways($Hmax, (64, 8, 512, 16, 1024, 20, 8192, 64));

# "open" bounds
DrCachesim::set_sets_ways($Hmin, (32, 1, 32, 1, 64, 1, 128, 1));
DrCachesim::set_sets_ways($Hmax, (512, 16, 1024, 16, 8192, 16, 2**15, 16));

my @cost_ratio = (1, 1, 1, 1, 0.1, 0.1, 0.01, 0.01);
my $cost_scale = 0.0001;
my @cost = map {$cost_scale * $_} @cost_ratio;

my $name = "imagick_r";
my $resf = "$DrCachesim::RESDIR/$name-res.yml";
my $jcfg = "$DrCachesim::ROOT/experiments/charact.jl";

my $P = DrCachesim::default_problem();

my $drargs = "-warmup_refs 10000 -retrace_every_instrs 800000 -trace_for_instrs 200000";
$P->{exe} = SpecInt::testrun_callback($name, $drargs);
$P->{cost} = DrCachesim::get_real_cost_fun(\@cost);
$P->{jcfg} = "$jcfg";

#DrCachesim::run_cachesim($P, $H0);

my $res = Optim::solve(P => $P, H0 =>$H0, Hmin => $Hmin, Hmax => $Hmax);

DumpFile($resf, $res);
system("notify-send $resf ready!")
