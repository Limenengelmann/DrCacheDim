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

my $H_capw = DrCacheDim::get_local_hierarchy();
DrCacheDim::set_sets_ways($H_capw, (64, 8, 512, 5, 512, 7, 2048, 17));
#DrCacheDim::set_sets_ways($H_capw, (64, 8, 512, 4, 512, 8, 2048, 16));
my $capway = RefGen::compile_code(RefGen::capway_code($H_capw));
my $H_2 = DrCacheDim::get_local_hierarchy();
#DrCacheDim::set_sets_ways($H_2, (64, 8, 512, 8, 512, 4, 2048, 16));
#DrCacheDim::set_sets_ways($H_2, (64, 8, 512, 7, 512, 4, 4096, 9));
DrCacheDim::set_sets_ways($H_2, (64, 8, 512, 5, 1024, 4, 4096, 9));
#DrCacheDim::set_sets_ways($H_2, (64, 8, 512, 1, 512, 2, 2048, 12));

my $Hmin = DrCacheDim::get_local_hierarchy();
my $Hmax = DrCacheDim::get_local_hierarchy();
my $H0 = DrCacheDim::get_local_hierarchy();
DrCacheDim::set_sets_ways($Hmin, (64, 8, 64, 2, 512, 4, 2048, 8));
DrCacheDim::set_sets_ways($Hmax, (64, 8, 512, 16, 1024, 20, 8192, 32));
DrCacheDim::set_sets_ways($H0, (64, 8, 64, 12, 1024, 20, 4096, 8)); # local config
my $P = DrCacheDim::default_problem($capway);
my $cscale  = DrCacheDim::get_cost_scaling_factor($P, $Hmin, $Hmax);
printf("cscale: $cscale\n");
($H_capw->{CSCALE}, $H_2->{CSCALE}) = ($cscale,$cscale);
($Hmin->{CSCALE}, $Hmax->{CSCALE}, $H0->{CSCALE}) = ($cscale, $cscale, $cscale);

($H_capw, $H_2) = DrCacheDim::parallel_run $P, [$H_capw, $H_2];

DrCacheDim::print_hierarchy($H_capw);
DrCacheDim::print_hierarchy($H_2);
printf("Val: %f vs H[VAL]: %f vs. formula: %f\n", $P->{val}->($H_2), $H_2->{VAL}, (0.5*$H_2->{CSCALE}*$H_2->{COST} + (1 - 0.5)*$H_2->{MAT}));
printf("H[COST]: %f, H[MAT]: %f, lambda: %f\n", $H_2->{COST}, $H_2->{MAT}, $H_2->{LAMBDA});
printf("H_cw[COST]: %f, H_cw[MAT]: %f, lambda: %f\n", $H_capw->{COST}, $H_capw->{MAT}, $H_capw->{LAMBDA});
