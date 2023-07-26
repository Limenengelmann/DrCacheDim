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


my $name = "imagick_r";
my @resfiles = <"$Aux::RESDIR/$name-char-*.yml">;

foreach my $resf (@resfiles) {
    my $S = LoadFile($resf);
    my $Hmin = $S->[0];
    my $Hmax = $S->[1];
    my $H0 = $S->[2];
    my $H_opt = $S->[-1];
    my $sims = @$S;

    print("$resf: ($sims Sims) \n");
    Aux::hierarchy2latex($Hmin, "Hmin");
    Aux::hierarchy2latex($Hmax, "Hmax");
    Aux::hierarchy2latex($H0, "H0");
    Aux::hierarchy2latex($H_opt, "H\\_opt");
}
