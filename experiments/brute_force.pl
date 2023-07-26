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
use List::Util qw( sample );

my $Hmin = DrCacheDim::get_local_hierarchy();
my $Hmax = DrCacheDim::get_local_hierarchy();

# "realistic" bounds from ./aux/cache-db
DrCacheDim::set_sets_ways($Hmin, (64, 8, 64, 2, 512, 4, 2048, 8));
DrCacheDim::set_sets_ways($Hmax, (64, 8, 512, 16, 1024, 20, 8192, 32));

# "open" bounds
#DrCacheDim::set_sets_ways($Hmin, (64, 8, 32, 1, 64, 1, 128, 1));
#DrCacheDim::set_sets_ways($Hmax, (64, 8, 1024, 16, 8192, 16, 2**15, 16));

#my $name = "matmul_ref";
#my ($name, $n) = "matmul_kji", 64;
#my $name = "x264_r";    # 210s per sim (or 1 min/sim multithreaded)
#my $name = "mcf_r";
#my $name = "xz_r";
my $name = "imagick_r";
my $tstamp = Aux::get_tstamp();
my $resf = "$Aux::RESDIR/$name-brutef-$tstamp.yml";


my $P = DrCacheDim::default_problem();
my $cscale = 1;
#my $P = DrCacheDim::default_problem("$Aux::ROOT/bin/$name $n");
# crashes x264_r when using this
#my $drargs = "";
my $drargs = $Aux::HEAD_ONLY_SIM;
$P->{exe} = SpecInt::testrun_callback($name, $drargs);
$P->{cost} = DrCacheDim::get_real_cost_fun();
$cscale  = DrCacheDim::get_cost_scaling_factor($P, $Hmin, $Hmax);
($Hmin->{CSCALE}, $Hmax->{CSCALE}) = ($cscale, $cscale);


my $hcube_sweep = DrCacheDim::cube_sweep($Hmin, $Hmax);
my $cap = 1000;
@$hcube_sweep = sample $cap, @$hcube_sweep;

@$hcube_sweep = DrCacheDim::parallel_run $P, $hcube_sweep;

DumpFile($resf, $hcube_sweep);
Aux::notify_when_done("$resf is done!");
printf "Wrote results to '$resf'\n";
