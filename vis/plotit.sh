#!/usr/bin/bash

path="/home/elimtob/Workspace/drcachedim/results/lambda-0.1"
plots="/home/elimtob/Workspace/drcachedim/plots"
folders=(
    "adpcm" 
    #"capway" 
    "CRC32" 
    "FFT" 
    "gsm" 
    "imagick_r" 
    "lbm_r" 
    #"matmul_kji" 
    #"matmul_ref"
);

for f in "${folders[@]}"; do
    #python pcoord.py "$path/$f/$f-char-*" "$f-char-pcoord.pdf" "$f - Characterisation" 10
    #python 2dplot.py "$path/$f/$f-char-*" "$f-char-2d.pdf"     "$f - Characterisation"

    python pcoord.py "$path/$f-max_mat-*" "$f-max_mat-0.1-pcoord.pdf" "$f - Limited MAT - lambda 0.1" 10
    python 2dplot.py "$path/$f-max_mat-*" "$f-max_mat-0.1-2d.pdf"     "$f - Limited MAT - lambda 0.1"

    python pcoord.py "$path/$f-max_cost-*" "$f-max_cost-0.1-pcoord.pdf" "$f - Limited Cost - lambda 0.1" 10
    python 2dplot.py "$path/$f-max_cost-*" "$f-max_cost-0.1-2d.pdf"     "$f - Limited Cost - lambda 0.1"
    #mkdir -p "$plots/lambda-0.1"
    #mv $plots/$f-* $plots/$f
done
