#!/bin/bash

dev=dev

for model in exp/chain/model/{all_tdnn_9_b,tdnn_lstm}; do
for i in $(seq 20 20 2000) final; do
   if [ -f $model/${i}.mdl ]; then
       sbatch common/chain_recog_iter.sh --dataset $dev --iter $i $model
   fi
done
done
