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

my $H0 = DrCachesim::get_local_hierarchy();
my $Hmin = DrCachesim::get_local_hierarchy();
my $Hmax = DrCachesim::get_local_hierarchy();

# "realistic" bounds from ./aux/cache-db
DrCachesim::set_sets_ways($Hmin, (64, 8, 64, 2, 512, 4, 2048, 8));
DrCachesim::set_sets_ways($Hmax, (64, 8, 512, 16, 1024, 20, 8192, 64));

# "open" bounds
#DrCachesim::set_sets_ways($Hmin, (32, 1, 32, 1, 64, 1, 128, 1));
#DrCachesim::set_sets_ways($Hmax, (512, 16, 1024, 16, 8192, 16, 2**15, 16));

my @cost_ratio = (1, 1, 1, 1, 0.1, 0.1, 0.01, 0.01);
my $cost_scale = 1; #0.00001
my @cost = map {$cost_scale * $_} @cost_ratio;

#my $name = "imagick_r";
#my $name = "x264_r";    # 210s per sim (or 1 min/sim multithreaded)
#my $name = "mcf_r";
my $name = "xz_r";
my $tstamp = Aux::get_tstamp();
my $resf = "$Aux::RESDIR/$name-res-$tstamp.yml";
my $jcfg = "$Aux::ROOT/experiments/charact.jl";

my $P = DrCachesim::default_problem();

# crashes x264_r when using this
#my $drargs = "-warmup_refs 10000 -retrace_every_instrs 800000 -trace_for_instrs 200000";
my $drargs = "";
$P->{exe} = SpecInt::testrun_callback($name, $drargs);
$P->{cost} = DrCachesim::get_real_cost_fun(\@cost);
$P->{jcfg} = "$jcfg";

#DrCachesim::run_cachesim($P, $H0);

my $tic = time();
my $res = Optim::solve(P => $P, H0 =>$H0, Hmin => $Hmin, Hmax => $Hmax);
my $toc = time() - $tic;
printf "Finished in %.2f s or %.2f m or %.2f h\n", $toc, $toc / 60 , $toc / 3600;

DumpFile($resf, $res);
Aux::notify_when_done("$resf is done!");
# PARAMS split
#[julia] Best hierarchy:
# 9 10 | 10 16 | 13  9 | 14  9 |      2515 156103210 156105725
#[julia] Exited loop with 0 queued problems after 32/100 iters.
#[julia] Purged 136 subproblems

# sets > ways simple split
#[julia] Best hierarchy:
# 9  9 | 10 16 | 13  9 | 14  8 |      2435 156102602 156105037
#[julia] Exited loop with 0 queued problems after 35/100 iters.
#[julia] Purged 142 subproblems
#
# greedy split
#[julia] Best hierarchy:
# 9  8 | 10 16 | 13 11 | 15  5 |      2574 156102502 156105076
#[julia] Exited loop with 12 queued problems after 100/100 iters.
#[julia] Purged 474 subproblems
