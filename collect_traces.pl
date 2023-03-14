use strict; 
use warnings;

my $specdir="/opt/spec-cpu2017";
my $drdir="/opt/DynamoRIO";
my $memtrdir="/home/elimtob/Workspace/mymemtrace";
my $dbdir="/mnt/extSSD/traces";

#speccpu params
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
        "../run_base_test_linux-amd64-m64.0000/x264_r_base.linux-amd64-m64 --dumpyuv 50 --frames 156 -o BuckBunny_New.264 BuckBunny.264 1280x720 "
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

sub process_and_instrument {
    my $r = shift;
    my $db = shift;

    my $pid = fork();
    if ($pid == 0) {
        exec("$memtrdir/build/process_memrefs $db");
    }

    #drrun does not forward the apps exit code :(
    my $ret = system(qq# drrun -root "$drdir" -c "$memtrdir/build/libmymemtrace_x86.so" -- $r #);

    #drrun does not forward the apps exit code, so we assume it works
    # but we make sure the app ran successfully in advance.
    waitpid $pid, 0;
    
    #if ($ret == 0) {
    #    waitpid $pid, 0;
    #} else {
    #    print "Ret $ret. Command failed: $!.\n";
    #    kill "SIGINT", $pid;
    #}
    return $ret;
}

# create traces!
print("-----------------------------------------------------------------------------------------------------------------\n");
print("-----------------------------------------------------------------------------------------------------------------\n");

die "$dbdir does not exist! Aborting.\n" unless (-d "$dbdir");

my @failed=();
my $succ=0;
while (my ($k, $v) = each(%$run)) {
    #print("k=$k, v=$v, rundir=$rundir\n");
    my $process="./build/process_memrefs";
    chdir("$specdir/");
    my $rdir=`source shrc; go $k run $rundir`; chomp $rdir;
    chdir($rdir) or print "Didn't work mate: $!\n";
    print "\nExecuting benchmark cmds for $k\n";
    #system("pwd; ls -l");
    foreach my $r (@$v) {
        #$r = "echo 'blabla'";  # for testing
        if (system($r) == 0) {
            $succ++;
            process_and_instrument($r, "$dbdir/$k-$size.db");
        } else {
            push @failed, ($r, $!);
        }
        last;
    }
    last;
}

print "Successfull cmds: $succ. Failed cmds: " . scalar(@failed). ".\n@failed\n";
exit 0;
