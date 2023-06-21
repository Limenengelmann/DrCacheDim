#!/usr/bin/perl
#package Optim;
use strict; 
use warnings;

use DrCachesim;
use YAML qw/ Load LoadFile Dump DumpFile /;

#TODO refactor to DrCachesim

sub hierarchy2yaml {
    my $H = shift;

    my $size0 = $H->{L1I}->{cfg}->{size};
    my $ways0 = $H->{L1I}->{cfg}->{assoc};
    my $size1 = $H->{L1D}->{cfg}->{size};
    my $ways1 = $H->{L1D}->{cfg}->{assoc};
    my $size2 = $H->{L2}->{cfg}->{size};
    my $ways2 = $H->{L2}->{cfg}->{assoc};
    my $size3 = $H->{L3}->{cfg}->{size};
    my $ways3 = $H->{L3}->{cfg}->{assoc};

    my $sets0 = $size0 / $ways0 / $DrCachesim::LINE_SIZE;
    my $sets1 = $size1 / $ways1 / $DrCachesim::LINE_SIZE;
    my $sets2 = $size2 / $ways2 / $DrCachesim::LINE_SIZE;
    my $sets3 = $size3 / $ways3 / $DrCachesim::LINE_SIZE;

    my $yH = {
        H => [
            $size0,
            $ways0,
            $size1,
            $ways1,
            $size2,
            $ways2,
            $size3,
            $ways3,
        ],
        VAL => $H->{VAL},
        AMAT => $H->{AMAT},
    };

    return Dump($yH);
}

sub yaml2hierarchy {
    my $yH = shift;
    $yH = Load($yH);
    my $H = DrCachesim::get_local_hierarchy();

    my ($size0, $ways0, 
        $size1, $ways1, 
        $size2, $ways2, 
        $size3, $ways3) = $yH->{H};

    $H->{L1I}->{cfg}->{size}  = $size0;
    $H->{L1I}->{cfg}->{assoc} = $ways0;
    $H->{L1D}->{cfg}->{size}  = $size1;
    $H->{L1D}->{cfg}->{assoc} = $ways1;
    $H->{L2}->{cfg}->{size}   = $size2;
    $H->{L2}->{cfg}->{assoc}  = $ways2;
    $H->{L3}->{cfg}->{size}   = $size3;
    $H->{L3}->{cfg}->{assoc}  = $ways3;

    $H->{VAL} = $yH0->{VAL};
    $H->{AMAT} = $yH0->{AMAT};

    return $H;
}

#TODO pass cost callback too
my $fname_in  = shift @ARGV;
my $fname_out = shift @ARGV;


my $S = LoadFile $fn;

my $rfile = DrCachesim::parallel_run $x, $sweep;
