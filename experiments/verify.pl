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

my $H = DrCachesim::get_local_hierarchy();
my $H0 = DrCachesim::get_local_hierarchy();
my $Hmin = DrCachesim::get_local_hierarchy();
my $Hmax = DrCachesim::get_local_hierarchy();

my $fn = RefGen::capway_code($H);
$fn = RefGen::compile_code $fn;

# "realistic" bounds from ./aux/cache-db
DrCachesim::set_sets_ways($Hmin, (64, 8, 64, 2, 512, 4, 2048, 8));
DrCachesim::set_sets_ways($Hmax, (64, 8, 512, 16, 1024, 20, 16384, 64));

DrCachesim::set_sets_ways($H0, (64, 8, 512, 7, 2048, 3, 16384, 15));

# "open" bounds
#DrCachesim::set_sets_ways($Hmin, (32, 1, 32, 1, 64, 1, 128, 1));
#DrCachesim::set_sets_ways($Hmax, (512, 16, 1024, 16, 8192, 16, 2**15, 16));

my @cost_ratio = (1, 1, 1, 1, 0.1, 0.1, 0.01, 0.01);
my $cost_scale = 0.001;
my @cost = map {$cost_scale * $_} @cost_ratio;

my $name = "capway";
my $resf = "$Aux::RESDIR/$name-res.yml";
my $jcfg = "$Aux::ROOT/experiments/charact.jl";

#my $drargs = "-warmup_refs 10000 -retrace_every_instrs 800000 -trace_for_instrs 200000";
my $P = DrCachesim::default_problem($fn);
$P->{cost} = DrCachesim::get_real_cost_fun(\@cost);
$P->{jcfg} = "$jcfg";

#DrCachesim::run_cachesim($P, $H0);
($H, $H0) = DrCachesim::parallel_run($P, [$H, $H0]);
my $res = Optim::solve(P => $P, H0 =>$H0, Hmin => $Hmin, Hmax => $Hmax, Hopt => $H);

print("[main] Start value\n");
DrCachesim::print_hierarchy($H0);
print("[main] Found solution:\n");
DrCachesim::print_hierarchy($res->[-1]);
print("[main] Theoretical Optimum: $fn\n");
DrCachesim::print_hierarchy($H);

DumpFile($resf, $res);
system("notify-send $resf ready!")
