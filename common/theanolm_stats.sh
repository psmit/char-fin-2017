#!/bin/bash

dir=$1

i=$(grep SLURM_ARRAY_JOB_ID $dir/log/theanolm.1.log | cut -f2 -d"=")
echo "Slurm job: '$i'"

slurm h 12day | grep -A1 $i | grep batch | awk '{print $6 " " $8}' |   common/theanolm_stats.py 
