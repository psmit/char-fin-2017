#!/bin/bash

export LC_ALL=C
set -euo pipefail

#prep=

xent_regularize=0.1
learning_rate_factor=5
leaky_hmm_coefficient=0.1
l2_regularize=0.00005
apply_deriv_weights=false

num_chunk_per_minibatch=128
initial_lrate=0.001
final_lrate=0.0001
max_param_change=2.0

num_epochs=4
preserve_model_interval=10

shrink_value=1.0

proportional_shrink=0.0
dropout_schedule=""

deriv_trunc_margin=0

left_context_initial=-1
right_context_final=-1
stage=-200

echo "$0 $@"  # Print the command line for logging


[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

if [ $# != 1 ]; then
   echo "usage: train_chain_model.sh config_name"
   exit 1;
fi

config_name=$1

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

. common/slurm_dep_graph.sh

JOB_PREFIX=$(cat id)_

. definitions/chain/model/$config_name
. exp/chain/prep/$prep/config

dir=exp/chain/model/$config_name
egs=exp/chain/prep/$prep/tdnn/egs

SDG_LOG_DIR=$dir/log

if [ $stage -le 0 ]; then
. $xconfig_template

mkdir -p $dir/configs
cp $xconfig $dir/configs/network.xconfig

steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/

fi
shift1=50
for start_stage in $(seq -$shift1 $shift1 1500); do
if [ $[${start_stage}+$shift1] -le $stage ]; then
continue
fi

real_start=$(($stage<$start_stage?$start_stage:$stage))
if [ $start_stage -lt -1 ]; then
SLURM_EXTRA_ARGS=" -c 6"
cmda="slurm.pl --mem 4G"
else
SLURM_EXTRA_ARGS=" -xgpu21,gpu22,gpu20 -c 10 -p gpu,gpushort --gres=gpu:4"
cmda="run2.pl"
fi
d1=""
d2=""
if [[ $deriv_trunc_margin > 0 ]]; then
d1="--trainer.deriv-truncate-margin"
d2=$deriv_trunc_margin
fi

if [ -d exp/chain/dataprep/$dataprep/data/train_comb ]; then
train_data=exp/chain/dataprep/$dataprep/data/train_comb
else
train_data=exp/chain/dataprep/$dataprep/data/train
fi

job chain_${start_stage} 4 4 LAST -- steps/nnet3/chain/train.py \
    --cmd "$cmda" \
    --feat.online-ivector-dir exp/chain/dataprep/$dataprep/ivec/ivectors_train \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false"\
    --chain.xent-regularize $xent_regularize \
    --chain.leaky-hmm-coefficient $leaky_hmm_coefficient \
    --chain.l2-regularize $l2_regularize \
    --chain.apply-deriv-weights $apply_deriv_weights \
    --chain.lm-opts="$chain_lm_opts"\
    --egs.dir "" \
    --egs.opts "--frames-overlap-per-eg $frames_overlap_per_eg" \
    --egs.chunk-width $chunk_width\
    --egs.chunk-right-context $chunk_right_context \
    --egs.chunk-left-context $chunk_left_context \
    --egs.chunk-left-context-initial $left_context_initial \
    --egs.chunk-right-context-final $right_context_final \
    --trainer.num-chunk-per-minibatch $num_chunk_per_minibatch \
    --trainer.frames-per-iter $frames_per_iter \
    --trainer.num-epochs $num_epochs \
    --trainer.optimization.num-jobs-initial 4 \
    --trainer.optimization.num-jobs-final 4 \
    --trainer.optimization.initial-effective-lrate $initial_lrate \
    --trainer.optimization.final-effective-lrate $final_lrate \
    --trainer.optimization.shrink-value $shrink_value \
    --trainer.optimization.proportional-shrink $proportional_shrink \
    --trainer.max-param-change $max_param_change \
    --trainer.dropout-schedule "$dropout_schedule" \
    --cleanup.remove-egs false \
    --feat-dir $train_data \
    --tree-dir exp/chain/prep/$prep/tree \
    --lat-dir exp/chain/dataprep/$dataprep/lats \
    --cleanup.preserve-model-interval $preserve_model_interval \
    $d1 $d2 \
    --dir $dir --stage $real_start --exit-stage $[${start_stage}+$shift1]
done

ln -rs exp/chain/dataprep/$dataprep/data $dir/feats
ln -rs exp/chain/dataprep/$dataprep/ivec $dir/ivecs
ln -rs exp/chain/prep/$prep/graph $dir/graph
exit
