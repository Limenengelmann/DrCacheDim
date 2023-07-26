#!/usr/bin/perl
use strict; 
use warnings;

use lib "/home/elimtob/Workspace/drcachedim/aux";
use DrCacheDim;
use Aux;
use Storable qw(dclone);

use List::Util qw( min max sum );
use YAML qw/ Load LoadFile Dump DumpFile /;

# e.g. rerun the same simulation, and check the variance of the latency (cost is constant, but should also be varied)
my $infile = shift;
die "Cannot find input file '$infile'!" unless -e $infile;
my $S = LoadFile($infile);
my $B = [];
my $P = DrCacheDim::default_problem();

my @cost_scales = map { 2**$_ } (-16 .. 16);
foreach my $cscale (@cost_scales) {
    my @cost = map {$cscale * $_} @DrCacheDim::DEFAULT_COST_RATIO;
    $P->{cost} = DrCacheDim::get_real_cost_fun(\@cost);
    #$P->{cost} = DrCacheDim::get_lin_cost_fun(\@cost);
    DrCacheDim::update_sims($P, $S);
    my $H_best = dclone(DrCacheDim::get_best($S));
    $H_best->{CSCALE} = $cscale;
    push @$B, $H_best;
}

$P->{cost} = DrCacheDim::get_real_cost_fun(\@DrCacheDim::DEFAULT_COST_RATIO);
# put all on the same scale to compare them better
DrCacheDim::update_sims($P, $B);

my $len = @$B;
my ($name) = $infile =~ /.*\/(.*).yml$/;
my $resf = "$Aux::RESDIR/cost-shift-$name.yml";
DumpFile($resf, $B);
printf "Wrote $len results to '$resf'\n";
