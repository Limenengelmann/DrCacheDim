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

my $name = shift || "capway";
my @resfiles = <"$Aux::RESDIR/$name-char-*.yml">;

foreach my $resf (@resfiles) {
    my $S = LoadFile($resf);
    my $Hmin = $S->[0];
    my $Hmax = $S->[1];
    my $H0 = $S->[2];
    my $H_opt = $S->[-1];
    # count unique hierarchies
    my %seen;
    my @unique = grep { !$seen{join("-", DrCacheDim::get_sets_ways($_))}++ } @$S;

    my $sims = @$S;
    my $uniq = @unique;

    print("$resf: ($uniq unique, $sims total Sims) \n");
    Aux::hierarchy2latex($Hmin, "Hmin");
    Aux::hierarchy2latex($Hmax, "Hmax");
    Aux::hierarchy2latex($H0, "H0");
    Aux::hierarchy2latex($H_opt, "H\\_opt");

    DrCacheDim::print_hierarchy($Hmin, "Hmin");
    DrCacheDim::print_hierarchy($Hmax, "Hmax");
    DrCacheDim::print_hierarchy($H0, "H0");
    DrCacheDim::print_hierarchy($H_opt, "H\\_opt");
}
