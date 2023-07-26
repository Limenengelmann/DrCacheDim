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
#DrCacheDim::set_sets_ways($Hmin, (64, 8, 64, 2, 512, 4, 2048, 8));
#DrCacheDim::set_sets_ways($Hmax, (64, 8, 512, 16, 1024, 20, 8192, 64));

# we know the working set of matmul 128 is 2*128^2 * 8 bytes = 64^3 = 64*64 cachelines, so we don't need a very high upper bound
# For n = 64: 2*64*64*8 = 2^10 cachelines for A*B, including C it becomes 2^11 > 3*2^9 > 2^10 cachelines in total
# One row/col occupies thus 16 cachelines, hence to compute one entry of C we need 32 cachelines (if storage order is good)
DrCacheDim::set_sets_ways($Hmin, (32, 1, 32, 1, 64, 1, 128, 1));
DrCacheDim::set_sets_ways($Hmax, (64, 8, 512, 2, 1024, 8, 8192, 16));

DrCacheDim::set_sets_ways($H0, (64, 8, 64, 2, 256, 4, 4096, 8));

my $cost_scale = 1; #0.00001
my @cost = map {$cost_scale * $_} @DynamoRIO::DEFAULT_COST_RATIO;

my $name = "matmul_ref";
#my $name = "matmul_kji";
my $n = 64;
my $tstamp = Aux::get_tstamp();
my $resf = "$Aux::RESDIR/$name-char-$tstamp.yml";
my $jcfg = "$Aux::ROOT/experiments/matmul.jl";

my $P = DrCacheDim::default_problem("$Aux::ROOT/bin/$name $n");

$P->{cost} = DrCacheDim::get_real_cost_fun(\@cost);
$P->{jcfg} = "$jcfg";

#DrCacheDim::run_cachesim($P, $H0);

my $tic = time();
my $res = Optim::solve(P => $P, H0 =>$H0, Hmin => $Hmin, Hmax => $Hmax);
my $toc = time() - $tic;
printf "Finished in %.2f s or %.2f m or %.2f h\n", $toc, $toc / 60 , $toc / 3600;

DumpFile($resf, $res);
Aux::notify_when_done("$resf is done!");
printf "Wrote results to '$resf'\n";
