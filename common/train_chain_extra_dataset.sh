#!/bin/bash

echo "$0 $@"  # Print the command line for logging
export LC_ALL=C

set -euo pipefail
IFS=$'\n\t'

train_set=
gmm=

speed_perturb=true
vol_perturb=true

mfcc_conf=mfcc_hires

min_seg_len=1.55

ivec_dim=512

[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

if [ $# != 2 ]; then
   echo "usage: train_chain_extra_dataset.sh config_name dataset"
   exit 1;
fi

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

config_name=$1
dset=$2
dname=$(basename $dset)
. common/slurm_dep_graph.sh

JOB_PREFIX=$(cat id)_

. definitions/chain/dataprep/$config_name

dir=exp/chain/dataprep/$config_name
SDG_LOG_DIR=$dir/log


data=$dir/data

set=$dname
job copy_h_$set 1 4 NONE -- utils/copy_data_dir.sh $dset $data/$set
job val1_$set 1 4 LAST -- utils/validate_data_dir.sh --no-feats $data/$set

numjobs=$(( $(wc -l < $dset/spk2utt) / 3 ))
numjobs_max=$(( $(wc -l < $dset/utt2spk) / 100 ))
numjobs=$(( $numjobs < $numjobs_max ? $numjobs : $numjobs_max ))
echo "$numjobs jobs"
job mfcc_hires_$set 1 4 LAST -- steps/make_mfcc.sh --mfcc-config conf/${mfcc_conf}.conf --cmd "$mfcc_cmd" --nj ${numjobs} $data/$set
job cmvn_hires_$set 1 4 LAST      -- steps/compute_cmvn_stats.sh $data/$set
job fix_hires_$set 4 4 LAST       -- utils/fix_data_dir.sh $data/$set
job val_data_$set 1 4 LAST        -- utils/validate_data_dir.sh $data/$set


ivec=$dir/ivec
numjobs=5
SLURM_EXTRA_ARGS="-c ${numjobs}"
job iv_${set} 4 4 LAST \
   -- steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $numjobs \
                                                  $data/$set $ivec/extractor \
                                                  $ivec/ivectors_$set
