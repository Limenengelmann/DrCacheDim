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
use List::Util qw( min max reduce );

my $H_capw = DrCacheDim::get_local_hierarchy();
DrCacheDim::set_sets_ways($H_capw, (64, 8, 512, 5, 512, 7, 2048, 17));
my $capway = RefGen::compile_code(RefGen::capway_code($H_capw));
my $mibench_path = "/home/elimtob/Workspace/telecomm";
my $exe = {
    #SPEC
    "imagick_r" => SpecInt::testrun_callback("imagick_r", $Aux::HEAD_ONLY_SIM),
    "lbm_r" => SpecInt::testrun_callback("lbm_r", $Aux::HEAD_ONLY_SIM),
    #Matmul
    "matmul_ref" => sub { return ("$Aux::ROOT/bin/matmul_ref 128", ""); },
    "matmul_kji" => sub { return ("$Aux::ROOT/bin/matmul_kji 128", ""); },
    #mibench
    "adpcm" => sub { chdir "$mibench_path/adpcm"; return ("bash runme_small.sh", ""); },
    "CRC32" => sub { chdir "$mibench_path/CRC32"; return ("bash runme_small.sh", ""); },
    "FFT"   => sub { chdir "$mibench_path/FFT"; return ("bash runme_small.sh", ""); },
    "gsm"   => sub { chdir "$mibench_path/gsm"; return ("bash runme_small.sh", ""); },
    #Capway
    #"capway" => sub { return ($capway, "");} 
};

my $N = 128;

foreach my $name (keys %$exe) {
    my @fnames = <"$Aux::RESDIR/$name/$name-char-*">;
    my $fn = $fnames[0] || die "No files found for $name!";
    my $S = LoadFile($fn);

    my $Hmin = $S->[0];
    my $Hmax = $S->[1];
    my $H0   = $S->[2];
    my $Hopt = $S->[-1];

    print("$fn: \n");
    #my $Hmin_mat = reduce { $a->{MAT} < $b->{MAT} ? $a : $b } @$S;
    #my $Hmax_mat = reduce { $a->{MAT} > $b->{MAT} ? $a : $b } @$S;
    #my $Hmin_cost = reduce { $a->{COST} < $b->{COST} ? $a : $b } @$S;
    #my $Hmax_cost = reduce { $a->{COST} > $b->{COST} ? $a : $b } @$S;
    #my $Hopt_ = DrCacheDim::get_best($S);
    #DrCacheDim::print_hierarchy($Hmin, "Hmin");
    #DrCacheDim::print_hierarchy($Hmin_cost, "Hmin_cost");
    #DrCacheDim::print_hierarchy($Hmax_mat, "Hmax_mat");
    #DrCacheDim::print_hierarchy($Hmax, "Hmax");
    #DrCacheDim::print_hierarchy($Hmax_cost, "Hmax_cost");
    #DrCacheDim::print_hierarchy($Hmin_mat, "Hmin_mat");
    #DrCacheDim::print_hierarchy($Hopt, "H\\_opt");
    #DrCacheDim::print_hierarchy($Hopt_, "Hopt_");
    #DrCacheDim::print_hierarchy($H0, "H0");


    my $resf = "$Aux::RESDIR/$name-variance.yml";
    my $P = DrCacheDim::default_problem();
    $P->{exe} = $exe->{$name};

    my $R = [];
    for (my $i=0; $i<$N; $i++) {
        push @$R, ($Hmin, $Hmax, $Hopt);
    }
    DrCacheDim::parallel_run($P, $R);
    DumpFile($resf, $R);
    Aux::notify_when_done("$resf is done!");
    system("perl show_sols.pl $fn");
    system("perl show_sols.pl $resf");
}
