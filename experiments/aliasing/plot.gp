#!/usr/bin/gnuplot

set term qt persist
#set term pdf
#set output "matmul_aliasing.pdf"
#set size ratio 0.5

set mouse

array arr[6]
arr[1] = "ijk"
arr[2] = "jik"
arr[3] = "ikj"
arr[4] = "kij"
arr[5] = "jki"
arr[6] = "kji"

# generate data
#do for [i=1:6] {
#    fname = "alias_" . arr[i] . ".data"
#    cmd = "lua aliasing.lua " . arr[i] . " > " . fname
#    system(cmd)
#}

set macros

set multiplot layout 3, 2 title "Aliasing Analysis" rowsfirst

#set palette defined (1 'blue', 2 'green', 3 'red')

set xrange [-0.05:1.05]
set xtics (0, 0.25, 0.5, 0.75 , 1)
set xtics font ",7"
set tics scale 0.5
set yrange [1:10]
set ytics (3, 5, 7, 9)
set ytics font ",7"
set grid ytics
# TODO set grid to finer than ytics
#set mytics 4

# Macros 
#tics
#NOXTICS = "set format x ''; unset xlabel"
#XTICS = "set format x '%.0f'; set xlabel 'time'"
XTICS = "set xtics ('0%%' 0, '25%%' 0.25, \"50%%\" 0.5, \"75%%\" 0.75, '100%%' 1); set xlabel 'runtime' font ',7'"
NOXTICS = "set xtics ('' 0, '' 0.25, '' 0.5, '' 0.75, '' 1); unset xlabel"

NOYTICS = "set format y ''; unset ylabel"
YTICS = "set format y '%.0f'; set ylabel 'avg. aliases' font ',7'"

#margins
TMARGIN = "set tmargin at screen 0.90; set bmargin at screen 0.63"
MMARGIN = "set tmargin at screen 0.63; set bmargin at screen 0.37"
BMARGIN = "set tmargin at screen 0.37; set bmargin at screen 0.10"

LMARGIN = "set lmargin at screen 0.15; set rmargin at screen 0.55"
RMARGIN = "set lmargin at screen 0.5499; set rmargin at screen 0.95"

LABELI = "set label 1 arr[i] at graph 0.9,0.9 font \",8\""
PLOTI = "plot \"data/alias_\".arr[i].\".data\" using ($1/12288):2 notitle with line linecolor \"blue\""

#PLOTI = "plot \"data/alias_\".arr[i].\".data\" using ($1/12288):2 notitle with line linecolor \"blue\""

i=1
@TMARGIN; @LMARGIN
@NOXTICS; @YTICS
@LABELI;
@PLOTI;

i=2
@TMARGIN; @RMARGIN
@NOXTICS; @NOYTICS
@LABELI;
@PLOTI;

i=3
@MMARGIN; @LMARGIN
@NOXTICS; @YTICS
@LABELI;
@PLOTI;

i=4
@MMARGIN; @RMARGIN
@NOXTICS; @NOYTICS
@LABELI;
@PLOTI;

i=5
@BMARGIN; @LMARGIN
@XTICS; @YTICS
@LABELI;
@PLOTI;

i=6
@BMARGIN; @RMARGIN
@XTICS; @NOYTICS
@LABELI;
@PLOTI;

unset multiplot
