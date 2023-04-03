#!/usr/bin/bash

specdir=/opt/spec-cpu2017
drdir=/opt/DynamoRIO
curdir=`pwd`
tuning="base"
size="test"
#cfg="base_refrate_linux-amd64-m64"
cfg="linux-amd64-m64"
builddir="build_${tuning}_$cfg.0000"
rundir="run_${tuning}_${size}_$cfg.0000"

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
    "cpuxalan_r"
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

#runcpu --fake --loose --size test --tune base --config linux-amd64 $c
#
cd $specdir; source "$specdir/shrc"
#for c in "${!runcmds[@]}"; do
for ii in "${!progs[@]}"; do
    c=${progs[$ii]}
    x="${exes[$ii]}_${tuning}.$cfg"
    go $c run $rundir
    #ls -l "$x"
    #XXX link binaries with their specinvoke name in the run directory
    #ln -s "../../build/$builddir/${exes[$ii]}" "$x"
    #rm "$x"
    #specinvoke -n | grep "$x"
    #ls "../../build/$builddir/${exe[$i]}"
    # specinvoke exe name: cpuxalan_r_base.linux-amd64-m64
    #echo "../../build/$builddir/${exes[$ii]}" "$x"
    #ls build/$builddir/$c
    #echo $c
    #go $c run $rundir
    #go $c build $builddir
    #find -maxdepth 1 -type f -executable 
done
