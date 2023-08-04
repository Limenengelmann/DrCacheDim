#!/usr/bin/bash

path="/home/elimtob/Workspace/drcachedim/results"
plots="/home/elimtob/Workspace/drcachedim/plots"
folders=(
    "imagick_r" 
    "lbm_r" 
    "matmul_kji" 
    "matmul_ref"
    "adpcm" 
    "CRC32" 
    "FFT" 
    "gsm" 
    #"capway" 
);

suffix="c100"
for f in "${folders[@]}"; do
    python pcoord.py "$path/$f-char-*" "$f-char-$suffix-pcoord.pdf" "$f - Characterisation - c100" 10
    python 2dplot.py "$path/$f-char-*" "$f-char-$suffix-2d.pdf"     "$f - Characterisation - c100"

    #python pcoord.py "$path/$f-max_mat-*" "$f-max_mat-$suffix-pcoord.pdf" "$f - Limited MAT - c100" 10
    #python 2dplot.py "$path/$f-max_mat-*" "$f-max_mat-$suffix-2d.pdf"     "$f - Limited MAT - c100"

    #python pcoord.py "$path/$f-max_cost-*" "$f-max_cost-$suffix-pcoord.pdf" "$f - Limited Cost - c100" 10
    #python 2dplot.py "$path/$f-max_cost-*" "$f-max_cost-$suffix-2d.pdf"     "$f - Limited Cost - c100"
    #mkdir -p "$plots/lambda-0.1"
    mv $plots/$f-* $plots/$f
done
