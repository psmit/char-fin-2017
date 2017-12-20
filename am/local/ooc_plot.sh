#!/bin/bash

scoredir=$1
vocab=$2


echo '\addplot[]'
echo 'coordinates {'
echo -n "(0,$(local/calc_find_oov_rate.sh $scoredir/scoring_kaldi/best_wer $vocab | cut -f5 -d" " ))"
for i in $(seq 1 15); do                                                     
echo -n " ($i,$(common/calc_oov_ooc_rates_lat.py $scoredir/all_words_$i $scoredir/scoring_kaldi/test_filt.txt $vocab | cut -f5 -d" "))"
done 

echo
echo '};'
echo '\addlegendentry{}'
