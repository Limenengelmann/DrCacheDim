#!/usr/bin/bash

specdir=~/.local/opt/spec-cpu2017
tuning="base"
size="test"
#cfg="base_refrate_linux-amd64-m64"
cfg="linux-amd64"

#-m64 automatically added by runcpu
builddir="build_${tuning}_$cfg-m64.0000"
rundir="run_${tuning}_${size}_$cfg-m64.0000"
curdir=`pwd`

progs=(
    "perlbench_r"
    "mcf_r"
    "omnetpp_r"
    "xalancbmk_r"
    "x264_r"
    "imagick_r"
    "xz_r"
)

exes=(
    "perlbench_r"
    "mcf_r"
    "omnetpp_r"
    "cpuxalan_r"    # different from progs!
    "x264_r"
    "imagick_r"
    "xz_r"
)

build=(
    #"perlbench_r"
    "specmake -j"
    #"mcf_r"
    "specmake -j"
    #"omnetpp_r"
    "specmake -j"
    #"xalancbmk_r"
    "specmake -j"
    #"x264_r"
    "specmake -j TARGET=x264_r"
    #"imagick_r"
    "specmake -j TARGET=imagick_r"
    #"xz_r"
    "specmake -j"
)

get_builddir() {
    local ii=$1
    runcpu --fake --loose --size $size --tune $tuning --config $cfg ${progs[$ii]}
    #go $c build $builddir
}

run_specmake() {
    local ii=$1
    local c=${progs[$ii]}
    local x="${exes[$ii]}_${tuning}.$cfg"

    #XXX: this call has side effects (like overwriting the local variable "i")
    go $c build $builddir
    ${build[$ii]}
    if [[ $? -ne 0 ]]; then
        test
        echo "run_specmake failed!"
        echo "i=$ii, c=$c, x=$x, buildcmd=${build[$ii]}"
        exit 1
    fi
}

link_exe(){
    local ii=$1
    local c=${progs[$ii]}
    local x="${exes[$ii]}_${tuning}.$cfg"

    go $c run $rundir
    #specinvoke -n | grep "$x"
    ln -sf `realpath "../../build/$builddir/${exes[$ii]}"` "$x"
    ls -l "$x";
}

cd $specdir; source "$specdir/shrc"
for ii in "${!progs[@]}"; do
    #get_builddir $ii
    #run_specmake $ii
    link_exe $ii
done
