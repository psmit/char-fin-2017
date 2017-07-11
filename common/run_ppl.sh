#!/bin/bash

. ./path.sh

dir=$1

segm_dir=$(dirname $dir)
data_dir=$(dirname $segm_dir)


if [ -f $dir/slurmjob_ppl ]; then
  if squeue -j $(cat $dir/slurmjob_ppl) >/dev/null 2>/dev/null; then
    echo "Job already running"
    exit 0;
  fi
fi

partitions="coin,batch-ivb,batch-wsm,batch-hsw,short-wsm,short-ivb,short-hsw"
ret=$(sbatch -p $partitions -t 4:00:00 --job-name=ppl -e $dir/log-%j.out -o $dir/log-%j.out --mem-per-cpu 4G -- common/train_vk_ppl.sh $dir)
echo $ret
rid=$(echo $ret | awk '{print $4;}')
echo "$rid" > $dir/slurmjob_ppl
