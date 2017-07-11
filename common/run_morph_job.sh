#!/bin/bash

. ./path.sh

dir=$1

parent_dir=$(dirname $dir)

if [ -f $dir/model.bin ] && [ -f $dir/model.txt ] && [ -f $dir/wordmap ] && [ -f $dir/vocab ]; then
  echo "Training already completed"
  exit 0;
fi

if [ -f $dir/slurmjob ]; then
  if squeue -j $(cat $dir/slurmjob) >/dev/null 2>/dev/null; then
    echo "Job already running"
    exit 0;
  fi
fi

partitions="coin,batch-ivb,batch-wsm,batch-hsw" #,short-ivb,short-wsm,short-hsw"
ret=$(sbatch -p $partitions -t 24:00:00 --job-name=morfessor -e $dir/log-%j.out -o $dir/log-%j.out --mem-per-cpu 4G -- common/train_morfessor.py $dir)
echo $ret
rid=$(echo $ret | awk '{print $4;}')
echo "$rid" > $dir/slurmjob
