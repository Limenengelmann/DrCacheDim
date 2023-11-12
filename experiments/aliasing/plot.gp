set term pdf
set output "plot.pdf"
#set size ratio 0.5

array arr[6]
arr[1] = "ijk"
arr[2] = "jik"
arr[3] = "ikj"
arr[4] = "kij"
arr[5] = "jki"
arr[6] = "kji"


set multiplot layout 3, 2 title "Aliasing Analysis"

#set palette defined (1 'blue', 2 'green', 3 'red')

set lmargin 5
set rmargin 5
set bmargin 5
set tmargin 5

#set xrange [0:9999]
set xlabel "X-axis" font ",7"
set ylabel "y-axis" font ",7"
set ylabel 'avg. aliases'
set xlabel 'time'
set xtics font ",7"
#set xtics (0, 2, 4, 6, 8, 10) scale 1000
#set ytics (0, 2, 4, 6, 8, 10)
set ytics (1, 3, 5, 7, 9)
set ytics font ",7"
set grid ytics mytics
# TODO set grid to finer than ytics
set mytics 4

unset colorbox

do for [i=1:6] {
    fname = "alias_" . arr[i] . ".data"
    #cmd = "lua aliasing.lua " . arr[i] . " > " . fname
    #system(cmd)
    #set output "plot_" . arr[i] . ".png"

    #plot for [col=2:3] @data using col #with line
    print fname
    set title arr[i] font ",8"
    plot "data/".fname using ($1/12288):2 notitle with line linecolor 'blue' #title arr[i]
}

unset multiplot

#  plot "alias_" . arr[1] . ".data" title arr[1]
#replot "alias_" . arr[2] . ".data" title arr[2]
#replot "alias_" . arr[3] . ".data" title arr[3]
#replot "alias_" . arr[4] . ".data" title arr[4]
#replot "alias_" . arr[5] . ".data" title arr[5]
#replot "alias_" . arr[6] . ".data" title arr[6]

