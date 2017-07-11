#!/bin/bash

echo "$0 $@"  # Print the command line for logging
export LC_ALL=C

set -euo pipefail
IFS=$'\n\t'

dataprep=

tree_numleaves=4000
leftmost_questions_truncate=-1

chunk_width=150
chunk_left_context=0
chunk_right_context=0
model_left_context=1
model_right_context=1
frames_overlap_per_eg=0
frames_per_iter=1500000
chain_lm_opts="--num-extra-lm-states=2000"  

left_context_initial=-1
right_context_final=-1


[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

if [ $# != 1 ]; then
   echo "usage: train_chain_prep.sh config_name"
   exit 1;
fi

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

config_name=$1

. common/slurm_dep_graph.sh

JOB_PREFIX=$(cat id)_

. definitions/chain/prep/$config_name

dir=exp/chain/prep/$config_name


dprep=exp/chain/dataprep/$dataprep
SDG_LOG_DIR=$dir/log

mkdir -p $dir/{log,egs,tree}
train_data_lores=$dprep/data/train_lores

if [ -d $dprep/data/train_comb ]; then
train_data=$dprep/data/train_comb
else
train_data=$dprep/data/train
fi
ali_dir=exp/chain/dataprep/$dataprep/ali

. definitions/chain/dataprep/$dataprep

cp -r $data_lang $dir/lang

steps/nnet3/chain/gen_topo.py $(cat $dir/lang/phones/silence.csl) \
                              $(cat $dir/lang/phones/nonsilence.csl) \
                               > $dir/lang/topo

SLURM_EXTRA_ARGS="-c 10"
#job build_tree 1 1 NONE -- \
steps/nnet3/chain/build_tree.sh --frame-subsampling-factor 3 \
      --context-opts "--context-width=2 --central-position=1" \
      --leftmost-questions-truncate $leftmost_questions_truncate \
      --cmd "slurm.pl --mem 4G" $tree_numleaves $train_data_lores $dir/lang $ali_dir $dir/tree


mkdir -p $dir/tdnn
ln -rs $dir/tdnn/egs $dir/egs

num_targets=$(tree-info $dir/tree/tree |grep num-pdfs|awk '{print $2}')
feat_dim=$(feat-to-dim scp:$train_data/feats.scp -)
ivec_dim=$(feat-to-dim scp:$dprep/ivec/ivectors_train/ivector_online.scp -)
learning_rate_factor=5

cat <<EOF > $dir/config
dataprep=$dataprep
tree_numleaves=$tree_numleaves
leftmost_questions_truncate=$leftmost_questions_truncate
chunk_width=$chunk_width
chunk_left_context=$chunk_left_context
chunk_right_context=$chunk_right_context
model_left_context=$model_left_context
model_right_context=$model_right_context
left_context_initial=$left_context_initial
right_context_final=$right_context_final
frames_overlap_per_eg=$frames_overlap_per_eg
frames_per_iter=$frames_per_iter
chain_lm_opts="$chain_lm_opts"
num_targets=$num_targets
feat_dim=$feat_dim
ivec_dim=$ivec_dim
EOF

mkdir -p $dir/tdnn/configs
cat <<EOF > $dir/tdnn/configs/network.xconfig
  input dim=$ivec_dim name=ivector
  input dim=$feat_dim name=input
  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
  fixed-affine-layer name=lda input=Append(-$model_left_context,0,$model_right_context,ReplaceIndex(ivector, t, 0)) affine-transform-file=$dir/tdnn/configs/lda.mat
  # the first splicing is moved before the lda layer, so no splicing here
  relu-renorm-layer name=tdnn1 dim=450
  ## adding the layers for chain branch
  relu-renorm-layer name=prefinal-chain input=tdnn1 dim=450 target-rms=0.5
  output-layer name=output include-log-softmax=false dim=$num_targets max-change=1.5
  # adding the layers for xent branch
  # This block prints the configs for a separate output that will be
  # trained with a cross-entropy objective in the 'chain' models... this
  # has the effect of regularizing the hidden parts of the model.  we use
  # 0.5 / args.xent_regularize as the learning rate factor- the factor of
  # 0.5 / args.xent_regularize is suitable as it means the xent
  # final-layer learns at a rate independent of the regularization
  # constant; and the 0.5 was tuned so as to make the relative progress
  # similar in the xent and regular final layers.
  relu-renorm-layer name=prefinal-xent input=tdnn1 dim=450 target-rms=0.5
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor max-change=1.5
EOF
steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/tdnn/configs/network.xconfig --config-dir $dir/tdnn/configs/

SLURM_EXTRA_ARGS="-c 5"
job chain_pre 2 4 NONE -- steps/nnet3/chain/train.py \
    --cmd "slurm.pl --mem 4G" \
    --feat.online-ivector-dir $dprep/ivec/ivectors_train \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.lm-opts="$chain_lm_opts" \
    --egs.opts "--frames-overlap-per-eg $frames_overlap_per_eg" \
    --egs.chunk-width $chunk_width \
    --egs.chunk-right-context $chunk_right_context \
    --egs.chunk-left-context $chunk_left_context \
    --egs.chunk-left-context-initial $left_context_initial \
    --egs.chunk-right-context-final $right_context_final \
    --trainer.frames-per-iter $frames_per_iter \
    --cleanup.remove-egs false \
    --feat-dir $train_data \
    --tree-dir $dir/tree \
    --lat-dir $dprep/lats \
    --dir $dir/tdnn \
    --stage -100 \
    --exit-stage 0

ln -rs $dir/tdnn/0.trans_mdl $dir/tdnn/final.mdl

SLURM_EXTRA_ARGS=""
job mkgraph 60 2 LAST -- utils/mkgraph.sh --self-loop-scale 1.0 $recog_lang $dir/tdnn $dir/graph 
