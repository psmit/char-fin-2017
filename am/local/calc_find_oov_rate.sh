#!/bin/bash

#[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

if [ $# -ne 2 ]; then
   echo "usage: local/calc_find_oov_rate.sh best_wer corpuslist"
   exit 1;
fi

bwer=$1
list=$2


hyp_file=$(cut -f14 -d" " $bwer | sed -E 's#wer_([0-9]+)_([0-9.]+)$#scoring_kaldi/penalty_\2/\1.txt#')
ref_file=$(dirname $bwer)/test_filt.txt

common/calc_oov_ooc_rates.py $hyp_file $ref_file $list

