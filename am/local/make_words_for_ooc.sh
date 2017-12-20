#!/bin/bash

for m in chars_aff morfessor_f2_a0.005_tokens_aff; do
for s in yle-dev-new parl-dev; do
for lmsuf in "" 10 "_domain" "10_domain"; do


 for i in $(seq 1 15); do 
if [ ! -f exp/chain/model/all_tdnn_blstm_9_a/decode1150_${s}_${m}${lmsuf}_rnn_interp/best/all_words_$i ]; then
sbatch common/get_word_from_lattices.sh --beam $i data/langs/${m}$(sed 's/_domain//' <<< $lmsuf) exp/chain/model/all_tdnn_blstm_9_a/decode1150_${s}_${m}${lmsuf}_rnn_interp/best/
fi
done
done
done
done
