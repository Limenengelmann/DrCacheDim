#!/usr/bin/bash

res="/home/elimtob/Workspace/drcachedim/results"
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
    "capway"
);

#suffix="c100-"
suffix=""
for f in "${folders[@]}"; do
    #python pcoord.py "$res/$f/$f-char-*" "$f-char-${suffix}pcoord.pdf" "$f - Characterisation" 10
    #python 2dplot.py "$res/$f/$f-char-*" "$f-char-${suffix}2d.pdf"     "$f - Characterisation"

    #python pcoord.py "$res/$f/$f-max_mat-*" "$f-max_mat-${suffix}pcoord.pdf" "$f - Limited MAT" 10
    python 2dplot.py "$res/$f/$f-max_mat-*" "$f-max_mat-${suffix}2d.pdf"     "$f - Limited MAT"

    #python pcoord.py "$res/$f/$f-max_cost-*" "$f-max_cost-${suffix}pcoord.pdf" "$f - Limited Cost" 10
    python 2dplot.py "$res/$f/$f-max_cost-*" "$f-max_cost-${suffix}2d.pdf"     "$f - Limited Cost"
    #mkdir -p "$plots/lambda-0.1"
    mv $plots/$f-* $plots/$f
done
