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

my $tstamp = Aux::get_tstamp();
my $lambda = 0.5;#0.1;
$tstamp = $tstamp . "-c100"; # . "-l0.1";
my $matmul_n = 128;
my $mibench_path = "/home/elimtob/Workspace/telecomm";
my $H_capw = DrCacheDim::get_local_hierarchy();
#DrCacheDim::set_sets_ways($H_capw, (64, 8, 512, 4, 512, 8, 2048, 16));
#DrCacheDim::set_sets_ways($H_capw, (64, 8, 128, 5, 512, 7, 2048, 13));
#DrCacheDim::set_sets_ways($H_capw, (64, 8, 256, 5, 512, 17, 2048, 9));
DrCacheDim::set_sets_ways($H_capw, (64, 8, 512, 5, 512, 7, 2048, 17));
my $capway = RefGen::compile_code(RefGen::capway_code($H_capw));

my $exe = {
    #SPEC
    "imagick_r" => SpecInt::testrun_callback("imagick_r", $Aux::HEAD_ONLY_SIM),
    "lbm_r" => SpecInt::testrun_callback("lbm_r", $Aux::HEAD_ONLY_SIM),
    #Matmul
    "matmul_ref" => sub { return ("$Aux::ROOT/bin/matmul_ref $matmul_n", ""); },
    "matmul_kji" => sub { return ("$Aux::ROOT/bin/matmul_kji $matmul_n", ""); },
    #mibench
    "adpcm" => sub { chdir "$mibench_path/adpcm"; return ("bash runme_small.sh", ""); },
    "CRC32" => sub { chdir "$mibench_path/CRC32"; return ("bash runme_small.sh", ""); },
    "FFT"   => sub { chdir "$mibench_path/FFT"; return ("bash runme_small.sh", ""); },
    "gsm"   => sub { chdir "$mibench_path/gsm"; return ("bash runme_small.sh", ""); },
    #Capway
    #"capway" => sub { return ($capway, "");}
};

sub init_H {
    my $Hmin = DrCacheDim::get_local_hierarchy();
    my $Hmax = DrCacheDim::get_local_hierarchy();
    my $H0 = DrCacheDim::get_local_hierarchy();

    # "realistic" bounds from ./aux/cache-db
    DrCacheDim::set_sets_ways($Hmin, (64, 8, 64, 2, 512, 4, 2048, 8));
    DrCacheDim::set_sets_ways($Hmax, (64, 8, 512, 16, 1024, 20, 8192, 32));
    DrCacheDim::set_sets_ways($H0, (64, 8, 64, 12, 1024, 20, 4096, 8)); # local config
    return ($Hmin, $Hmax, $H0);
}

sub bruteforce {
    my $name = shift;
    my $Hmin = shift;
    my $Hmax = shift;

    my $P = DrCacheDim::default_problem();
    $P->{exe} = $exe->{$name};

    my $hcube_sweep = DrCacheDim::cube_sweep($Hmin, $Hmax);
    my $cap = 100;
    @$hcube_sweep = sample $cap, @$hcube_sweep;
    @$hcube_sweep = DrCacheDim::parallel_run $P, $hcube_sweep;

    my $resf = "$Aux::RESDIR/$name-brutef-$tstamp.yml";
    DumpFile($resf, $hcube_sweep);
    Aux::notify_when_done("$resf is done!");
    printf "Wrote results to '$resf'\n";
}

sub characterisation {
    my $name = shift;
    my $Hmin = shift;
    my $Hmax = shift;
    my $H0   = shift;

    my $P = DrCacheDim::default_problem();
    $P->{exe} = $exe->{$name};
    $P->{jcfg} = "$Aux::ROOT/experiments/charact.jl";

    my $tic = time();
    my $res = Optim::solve(P => $P, H0 =>$H0, Hmin => $Hmin, Hmax => $Hmax);
    my $toc = time() - $tic;
    printf "Characterisation finished in %.2f s or %.2f m or %.2f h\n", $toc, $toc / 60 , $toc / 3600;

    my $resf = "$Aux::RESDIR/$name-char-$tstamp.yml";
    DumpFile($resf, $res);
    Aux::notify_when_done("$resf is done!");
    printf "Wrote results to '$resf'\n";
    return $res;
}

sub max_cost {
    my $name = shift;
    my $max_cost = shift;
    my $Hmin = shift;
    my $Hmax = shift;
    my $H0   = shift;


    my $jcfg = "$Aux::ROOT/experiments/max_cost.jl";
    # hacky way to set max_cost in jcfg
    system("sed -i 's/^max_cost = .*\$/max_cost = $max_cost/' $jcfg") == 0 or die;

    my $P = DrCacheDim::default_problem();
    $P->{exe} = $exe->{$name};
    $P->{val} = sub { my $H = shift; return $H->{COST} > $max_cost ? $Aux::BIG_VAL : DrCacheDim::default_val($H); };
    $P->{jcfg} = "$jcfg";

    my $tic = time();
    my $res = Optim::solve(P => $P, H0 =>$H0, Hmin => $Hmin, Hmax => $Hmax);
    my $toc = time() - $tic;
    printf "max_cost finished in %.2f s or %.2f m or %.2f h\n", $toc, $toc / 60 , $toc / 3600;

    $max_cost = int($max_cost);
    my $resf = "$Aux::RESDIR/$name-max_cost-$max_cost-$tstamp.yml";
    DumpFile($resf, $res);
    Aux::notify_when_done("$resf is done!");
    printf "Wrote results to '$resf'\n";
    return $res;
}

sub max_mat {
    my $name = shift;
    my $max_mat = shift;
    my $Hmin = shift;
    my $Hmax = shift;
    my $H0   = shift;

    my $jcfg = "$Aux::ROOT/experiments/max_mat.jl";
    system("sed -i 's/^max_mat = .*\$/max_mat = $max_mat/' $jcfg") == 0 or die;

    my $P = DrCacheDim::default_problem();
    $P->{exe} = $exe->{$name};
    $P->{jcfg} = "$jcfg";
    $P->{val} = sub { my $H = shift; return $H->{MAT} > $max_mat ? $Aux::BIG_VAL : DrCacheDim::default_val($H); };

    my $tic = time();
    my $res = Optim::solve(P => $P, H0 =>$H0, Hmin => $Hmin, Hmax => $Hmax);
    my $toc = time() - $tic;
    printf "max_mat finished in %.2f s or %.2f m or %.2f h\n", $toc, $toc / 60 , $toc / 3600;

    $max_mat = int($max_mat);
    my $resf = "$Aux::RESDIR/$name-max_mat-$max_mat-$tstamp.yml";
    DumpFile($resf, $res);
    Aux::notify_when_done("$resf is done!");
    printf "Wrote results to '$resf'\n";
    return $res;
}

sub analysis {
    my $name = shift;
    my $P = DrCacheDim::default_problem();
    $P->{exe} = $exe->{$name};
    DrCacheDim::run_analysistool($P, "-simulator_type reuse_distance");
    DrCacheDim::run_analysistool($P, "-simulator_type basic_counts");
}

foreach my $name (keys %$exe) {
    printf("Benchmarking $name.\n");
    my ($Hmin, $Hmax, $H0) = init_H();
    my $P = DrCacheDim::default_problem();
    $P->{exe} = $exe->{$name};
    my $cscale  = DrCacheDim::get_cost_scaling_factor($P, $Hmin, $Hmax);
    DrCacheDim::set_cscale_lambda([$Hmin, $Hmax, $H0], $cscale, $lambda);
    DrCacheDim::run_cachesim($P, $H0);
    my $max_mat = $H0->{MAT};
    my $max_cost = $H0->{COST};
    if ($name eq "capway") {
        # optimum MAT and COST
        $max_mat = 9346990;
        $max_cost = 1620706;
    }
    printf("Scaling cost with factor: %f\n", $H0->{CSCALE});

    my $S = [];
    $S = characterisation $name, $Hmin, $Hmax, $H0;
    max_cost $name, $max_cost, $Hmin, $Hmax, $H0;
    max_mat $name, $max_mat, $Hmin, $Hmax, $H0;
    #bruteforce $name, $Hmin, $Hmax;
    #analysis $name;
}
