#!/usr/bin/perl
use strict; 
use warnings;

use lib "/home/elimtob/Workspace/mymemtrace/aux";
use RefGen;
use SpecInt;
use DrCachesim;
use Optim;
use Aux;

use List::Util qw( min max sum );
use YAML qw/ Load LoadFile Dump DumpFile /;

sub analyse_var {
    my $S = shift;
    my $n = @$S;

    my @Lat = map {$_->{MAT}} @$S;
    my $min = min @Lat;
    my $max = max @Lat;
    my $avg = sum(map {$_ / $n} @Lat);
    my $var = sum(map {($_/$max - $avg/$max)**2 / $n} @Lat);
    return {min => $min, max => $max, avg => $avg, var => sqrt($var)};
}

sub print_var {
    my $name = shift;
    my $V = shift;
    printf "%s latency: min: %d, max: %d, avg: %f, normalized var: %e\n", $name,
        $V->{min}, $V->{max}, $V->{avg}, $V->{var};
}

#TODO variance test
# e.g. rerun the same simulation, and check the variance of the latency (cost is constant, but should also be varied)
my $H0 = DrCachesim::get_local_hierarchy();
my $Hmin = DrCachesim::get_local_hierarchy();
my $Hmax = DrCachesim::get_local_hierarchy();
#
## "open" bounds
DrCachesim::set_sets_ways($Hmin, (32, 1, 32, 1, 64, 1, 128, 1));
DrCachesim::set_sets_ways($Hmax, (512, 16, 1024, 16, 8192, 16, 2**15, 16));
#
my $name = "imagick_r";
$name = "xz_r";
$name = "imagick_r";
my $tstamp = Aux::get_tstamp();
my $resf = "$Aux::RESDIR/$name-variance.yml";
#
my $P = DrCachesim::default_problem();
#
$P->{exe} = SpecInt::testrun_callback($name);
#
my $N = 0;
my $R = [];
my $S = LoadFile($resf) if -e $resf;
#
for (my $i=0; $i<$N; $i++) {
    push @$R, ($Hmin, $Hmax, $H0);
}
if ($N > 0) {
    DrCachesim::parallel_run($P, $R) if $N > 0;
    push @$S, @$R;
    DumpFile($resf, $S) if $N > 0;
    Aux::notify_when_done("$resf is done!");
}

$N = @$S;
$N /= 3;

my $V;
my @Smin = map { $_ % 3 == 0 ? $S->[$_] : () } (0 .. $N-1);
print_var("Hmin", analyse_var(\@Smin));
my @Smax = map { $_ % 3 == 1 ? $S->[$_] : () } (0 .. $N-1);
print_var("Hmax", analyse_var(\@Smax));
my @S0 = map { $_ % 3 == 2 ? $S->[$_] : () } (0 .. $N-1);
print_var("H0", analyse_var (\@S0));

