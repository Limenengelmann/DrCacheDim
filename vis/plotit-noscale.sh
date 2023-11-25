#!/usr/bin/bash

res="/home/elimtob/Workspace/drcachedim/results"
plots="/home/elimtob/Workspace/drcachedim/plots"
outdir="/home/elimtob/thesis_report/fig"

#suffix=""
#python pcoord.py "$res/imagick_r/imagick_r-char-7-28-1-24-18.yml" "imagick_r-char-${suffix}pcoord.pdf" "imagick_r - Characterisation" 10
#python 2dplot.py "$res/imagick_r/imagick_r-char-7-28-1-24-18.yml" "imagick_r-char-${suffix}2d.pdf" "imagick_r - Characterisation"

suffix="small-"
python 2dplot.py "$res/nocscale-lbm_r-char-updated.yml" "noscale_lbm_r-cost-mat.pdf" ""
python 2dplot.py "$res/imagick_r/imagick_r-brutef-8-25-22-2-19.yml" "imagick_r-BF-${suffix}2d.pdf" " "
python pcoord.py "$res/imagick_r/imagick_r-char-7-28-1-24-18.yml" "imagick_r-char-${suffix}pcoord.pdf" " " 10
python pcoord.py "$res/imagick_r/imagick_r-brutef-8-25-22-2-19.yml" "imagick_r-BF-${suffix}pcoord.pdf" " " 10

#suffix="small-"
#python pcoord.py "$res/adpcm/adpcm-char-7-28-1-24-18.yml" "adpcm-char-${suffix}pcoord.pdf" " " 10
#python pcoord.py "$res/CRC32/CRC32-char-7-28-1-24-18.yml" "CRC32-char-${suffix}pcoord.pdf" " " 10
#python pcoord.py "$res/FFT/FFT-char-7-28-1-24-18.yml" "FFT-char-${suffix}pcoord.pdf" " " 10
#python pcoord.py "$res/gsm/gsm-char-7-28-1-24-18.yml" "gsm-char-${suffix}pcoord.pdf" " " 10

#python pcoord.py "$res/$f/$f-char-*" "$f-char-${suffix}pcoord.pdf" "$f - Characterisation" 10
#python 2dplot.py "$res/$f/$f-char-*" "$f-char-${suffix}2d.pdf"     "$f - Characterisation"

#python pcoord.py "$res/$f/$f-max_mat-*" "$f-max_mat-${suffix}pcoord.pdf" "$f - Limited MAT" 10
#python 2dplot.py "$res/$f/$f-max_mat-*" "$f-max_mat-${suffix}2d.pdf"     "$f - Limited MAT"

#python pcoord.py "$res/$f/$f-max_cost-*" "$f-max_cost-${suffix}pcoord.pdf" "$f - Limited Cost" 10
#python 2dplot.py "$res/$f/$f-max_cost-*" "$f-max_cost-${suffix}2d.pdf"     "$f - Limited Cost"
#mkdir -p "$plots/lambda-0.1"
#mv $plots/$f-* $plots/$f
