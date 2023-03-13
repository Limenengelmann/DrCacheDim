use strict; 
use warnings;
use Cwd qw(getcwd);

my $specdir="/opt/spec-cpu2017";
my $drdir="/opt/DynamoRIO";
my $outdir="~/Workspace/mymemtrace/data";

my $tuning="base";
my $size="test";

#cfg="base_refrate_linux-amd64-m64"
my $cfg="linux-amd64-m64";
my $builddir="build_${tuning}_$cfg.0000";
my $rundir="run_${tuning}_${size}_$cfg.0000";
my $src="source $specdir/shrc";

my $run={
    "perlbench_r" => [
        "../run_base_test_linux-amd64-m64.0000/perlbench_r_base.linux-amd64-m64 -I. -I./lib makerand.pl ",
        "../run_base_test_linux-amd64-m64.0000/perlbench_r_base.linux-amd64-m64 -I. -I./lib test.pl "
    ],

    "mcf_r" =>  [
        "../run_base_test_linux-amd64-m64.0000/mcf_r_base.linux-amd64-m64 inp.in  "
    ],

    "omnetpp_r" => [
        "../run_base_test_linux-amd64-m64.0000/omnetpp_r_base.linux-amd64-m64 -c General -r 0 "
    ],

    "xalancbmk_r" => [
        "../run_base_test_linux-amd64-m64.0000/cpuxalan_r_base.linux-amd64-m64 -v test.xml xalanc.xsl "
    ],

    "x264_r" => [
        "../run_base_test_linux-amd64-m64.0000/x264_r_base.linux-amd64-m64 --dumpyuv 50 --frames 156 -o BuckBunny_New.264 BuckBunny.yuv 1280x720 "
    ],

    "imagick_r" => [
        "../run_base_test_linux-amd64-m64.0000/imagick_r_base.linux-amd64-m64 -limit disk 0 test_input.tga -shear 25 -resize 640x480 -negate -alpha Off test_output.tga "
    ],

    "xz_r" => [
        "../run_base_test_linux-amd64-m64.0000/xz_r_base.linux-amd64-m64 cpu2006docs.tar.xz 4 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 1548636 1555348 0 ",
        "../run_base_test_linux-amd64-m64.0000/xz_r_base.linux-amd64-m64 cpu2006docs.tar.xz 4 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 1462248 -1 1 ",
        "../run_base_test_linux-amd64-m64.0000/xz_r_base.linux-amd64-m64 cpu2006docs.tar.xz 4 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 1428548 -1 2 ",
        "../run_base_test_linux-amd64-m64.0000/xz_r_base.linux-amd64-m64 cpu2006docs.tar.xz 4 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 1034828 -1 3e ",
        "../run_base_test_linux-amd64-m64.0000/xz_r_base.linux-amd64-m64 cpu2006docs.tar.xz 4 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 1061968 -1 4 ",
        "../run_base_test_linux-amd64-m64.0000/xz_r_base.linux-amd64-m64 cpu2006docs.tar.xz 4 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 1034588 -1 4e ",
        "../run_base_test_linux-amd64-m64.0000/xz_r_base.linux-amd64-m64 cpu2006docs.tar.xz 1 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 650156 -1 0 ",
        "../run_base_test_linux-amd64-m64.0000/xz_r_base.linux-amd64-m64 cpu2006docs.tar.xz 1 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 639996 -1 1 ",
        "../run_base_test_linux-amd64-m64.0000/xz_r_base.linux-amd64-m64 cpu2006docs.tar.xz 1 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 637616 -1 2 ",
        "../run_base_test_linux-amd64-m64.0000/xz_r_base.linux-amd64-m64 cpu2006docs.tar.xz 1 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 628996 -1 3e ",
        "../run_base_test_linux-amd64-m64.0000/xz_r_base.linux-amd64-m64 cpu2006docs.tar.xz 1 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 631912 -1 4 ",
        "../run_base_test_linux-amd64-m64.0000/xz_r_base.linux-amd64-m64 cpu2006docs.tar.xz 1 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 629064 -1 4e ",
    ],
};

# create traces!
print("-----------------------------------------------------------------------------------------------------------------\n");
print("-----------------------------------------------------------------------------------------------------------------\n");

my $cwd = `pwd`; chomp $cwd;
while (my ($k, $v) = each(%$run)) {
    #print("k=$k, v=$v, rundir=$rundir\n");
    my $process="./build/process_memrefs";
    chdir("$specdir/");
    my $rdir=`source shrc; go $k run $rundir`; chomp $rdir;
    chdir($rdir) or print "Didn't work mate: $!\n";
}

chdir($cwd);    # change back to original dir

my $pid = fork();
if ($pid == 0) {
    exec("./build/process_memrefs ./data/bla.db");
}

my $ret = system("drrun -root $drdir -c build/libmymemtrace_x86.so -- echo 'blablabla'");

if ($ret == 0) {
    print "Command failed: $!.\n"; 
    kill "SIGINT", $pid;
} else {
    waitpid $pid, 0;
}
