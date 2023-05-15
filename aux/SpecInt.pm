package SpecInt;

use strict;
use warnings;

#speccpu params
our $tuning = "base";
our $size   = "test";
our $specdir    = "/home/elimtob/.local/opt/spec-cpu2017";

our $cfg      = "linux-amd64";
our $builddir = "build_${tuning}_$cfg-m64.0000";
our $rundir   = "run_${tuning}_${size}_$cfg-m64.0000";

#NOTE: Make sure the file names are correct, specint adds file endings based on the configs name!
our $test_run = {
    "perlbench_r" => [
        "./perlbench_r_base.linux-amd64 -I. -I./lib makerand.pl ",
        "./perlbench_r_base.linux-amd64 -I. -I./lib test.pl "
    ],

    "mcf_r" =>  [
        "./mcf_r_base.linux-amd64 inp.in  "
    ],

    "omnetpp_r" => [
        "./omnetpp_r_base.linux-amd64 -c General -r 0 "
    ],

    "xalancbmk_r" => [
        "./cpuxalan_r_base.linux-amd64 -v test.xml xalanc.xsl "
    ],

    "x264_r" => [
        "./x264_r_base.linux-amd64 --dumpyuv 50 --frames 156 -o BuckBunny_New.264 BuckBunny.264 1280x720 "
    ],

    "imagick_r" => [
        "./imagick_r_base.linux-amd64 -limit disk 0 test_input.tga -shear 25 -resize 640x480 -negate -alpha Off test_output.tga "
    ],

    "xz_r" => [
        "./xz_r_base.linux-amd64 cpu2006docs.tar.xz 4 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 1548636 1555348 0 ",
        "./xz_r_base.linux-amd64 cpu2006docs.tar.xz 4 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 1462248 -1 1 ",
        "./xz_r_base.linux-amd64 cpu2006docs.tar.xz 4 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 1428548 -1 2 ",
        "./xz_r_base.linux-amd64 cpu2006docs.tar.xz 4 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 1034828 -1 3e ",
        "./xz_r_base.linux-amd64 cpu2006docs.tar.xz 4 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 1061968 -1 4 ",
        "./xz_r_base.linux-amd64 cpu2006docs.tar.xz 4 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 1034588 -1 4e ",
        "./xz_r_base.linux-amd64 cpu2006docs.tar.xz 1 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 650156 -1 0 ",
        "./xz_r_base.linux-amd64 cpu2006docs.tar.xz 1 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 639996 -1 1 ",
        "./xz_r_base.linux-amd64 cpu2006docs.tar.xz 1 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 637616 -1 2 ",
        "./xz_r_base.linux-amd64 cpu2006docs.tar.xz 1 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 628996 -1 3e ",
        "./xz_r_base.linux-amd64 cpu2006docs.tar.xz 1 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 631912 -1 4 ",
        "./xz_r_base.linux-amd64 cpu2006docs.tar.xz 1 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 629064 -1 4e ",
    ],
};

sub chdir {
    # NOTE: needs /usr/bin/sh to point to bash or zsh, dash does not work with "source"
    my $x = shift;
    chdir("$specdir");
    my $rdir=`source shrc; go $x run $rundir`; 
    chomp $rdir;
    chdir($rdir) or die "[SpecInt::chdir] Can't change into '$rdir': $!\n";
    #print "[SpecInt::chdir] Cwd: ". `pwd`;
}

sub testrun_dispatcher {
    my $k = shift;
    my $cb = sub {
        SpecInt::chdir $k;
        my $cmd = %$test_run{$k}->[0];
        my $drargs = "";
        return ($cmd, $drargs);
    };
    return $cb;
}
