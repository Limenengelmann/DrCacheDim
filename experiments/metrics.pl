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

#cache, miss_analyzer, TLB, histogram, reuse_distance, basic_counts, opcode_mix, view or func_view
my $name = "imagick_r";
my $drargs = $Aux::HEAD_ONLY_SIM;
my $P = DrCacheDim::default_problem();
$P->{exe} = SpecInt::testrun_callback($name, $drargs);

DrCacheDim::run_analysistool($P, "-simulator_type reuse_distance");
#DrCacheDim::run_analysistool($P, "-simulator_type reuse_time -reuse_histogram_bin_multiplier 1.05");
DrCacheDim::run_analysistool($P, "-simulator_type basic_counts");
