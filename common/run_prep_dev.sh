#!/bin/bash

. ./path.sh

dir=$1

segm_dir=$(dirname $dir)
data_dir=$(dirname $segm_dir)

depend=""
if [ ! -f $segm_dir/wordmap_all ]; then
  if [ -f $segm_dir/slurmjob-dev ]; then
    echo "adding dependency"
    depend="--dependency=afterok:$(cat $segm_dir/slurmjob-dev)"
  else
    echo "segm job has not run yet"
    exit 1;
  fi
fi

if [ -f $dir/slurmjob-dev ]; then
  if squeue -j $(cat $dir/slurmjob-dev) >/dev/null 2>/dev/null; then
    echo "Job already running"
    exit 0;
  fi
fi


partitions="coin,batch-ivb,batch-wsm,batch-hsw,short-wsm,short-ivb,short-hsw"
ret=$(sbatch -p $partitions -t 4:00:00 --job-name=varikn-prep -e $dir/log-%j.out -o $dir/log-%j.out --mem-per-cpu 4G $depend -- common/prep_dev.py $dir)
echo $ret
rid=$(echo $ret | awk '{print $4;}')
echo "$rid" > $dir/slurmjob-dev
