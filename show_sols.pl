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

my $name = shift || die "No filename provided!";
my @resfiles = <"$name">;

sub show_variance {
    my $resf = shift;

    my $S = LoadFile($resf) || die "File '$resf' not found";
    my $N = @$S;

    #XXX: S is sorted as Hmin, Hmax, Hopt, Hmin, Hmax, Hopt,...
    my @Smin = map { $_ % 3 == 0 ? $S->[$_] : () } (0 .. $N-1);
    my @Smax = map { $_ % 3 == 1 ? $S->[$_] : () } (0 .. $N-1);
    my @Sopt = map { $_ % 3 == 2 ? $S->[$_] : () } (0 .. $N-1);
    #my %seen;
    #my @unique = grep { !$seen{$_->{COST}}++ } @$S;

    #my @Smin = grep {$_->{COST} == $unique[0]->{COST}} @$S;
    #my @Smax = grep {$_->{COST} == $unique[1]->{COST}} @$S;
    #my @Sopt = grep {$_->{COST} == $unique[-1]->{COST}} @$S;
    my $latex = 1;
    Aux::analyse_stddev("Hmin", \@Smin, $latex);
    Aux::analyse_stddev("Hmax", \@Smax, $latex);
    Aux::analyse_stddev("Hopt", \@Sopt, $latex);
}

foreach my $resf (@resfiles) {
    if ($resf =~ /variance\.yml/) {
        print("$resf: \n");
        show_variance($resf);
    } else {
        my $S = LoadFile($resf);
        my $Hmin = $S->[0];
        my $Hmax = $S->[1];
        my $H0 = $S->[2];
        my $H_opt = DrCacheDim::get_best($S);
        # count unique hierarchies
        my %seen;
        my @unique = grep { !$seen{join("-", DrCacheDim::get_sets_ways($_))}++ } @$S;
        my %seen2;
        map { $seen2{$_->{COST}}++ } @unique;
        my @double_cost = grep { $seen2{$_->{COST}}>=2 } @unique;
        @double_cost = sort {$a->{COST} <=> $b->{COST}} @double_cost;

        my $sims = @$S;
        my $uniq = @unique;
        my $dup_cost = @double_cost;

        print("$resf: ($uniq unique, $sims total Sims!) \n");
        Aux::hierarchy2latex($Hmin, "Hmin");
        Aux::hierarchy2latex($Hmax, "Hmax");
        Aux::hierarchy2latex($H0, "H0");
        Aux::hierarchy2latex($H_opt, "H\\_opt");

        DrCacheDim::print_hierarchy($Hmin, "Hmin");
        DrCacheDim::print_hierarchy($Hmax, "Hmax");
        DrCacheDim::print_hierarchy($H0, "H0");
        DrCacheDim::print_hierarchy($H_opt, "H\\_opt");

        #foreach my $H (@double_cost) {
        #    DrCacheDim::print_hierarchy($H, "Hcost");
        #}
    }
}
