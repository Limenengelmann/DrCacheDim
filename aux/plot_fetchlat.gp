set terminal png size 900, 500
set output "random-chase.png"
set xlabel "memory area in bytes"
set logscale x
set ylabel "avg access time in ns"
set title "Access times in dependence of memory area"
set key out
set pointsize 0.5

# determine maximal y value by plotting to a dummy terminal
set terminal push
set terminal unknown
plot "../config/random-chase.out" using 2
set terminal pop

# mark L1, L2, and L3:
maxy = GPVAL_Y_MAX
l1 = 32
l2 = 256
l3 = 8192
set arrow from l1*1024,0 to l1*1024,maxy nohead lc rgb 'blue';
set arrow from l2*1024,0 to l2*1024,maxy nohead lc rgb 'blue';
set arrow from l3*1024,0 to l3*1024,maxy nohead lc rgb 'blue';

plot "../config/random-chase.out" using 1:2 with linespoints lt 2 title "Intel Xeon 5650"
