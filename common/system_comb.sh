#!/usr/bin/bash 
#SBATCH -p coin,batch-hsw,batch-wsm,batch-ivb
#SBATCH -t 14:00:00
#SBATCH -n 1
#SBATCH --cpus-per-task=3
#SBATCH -N 1
#SBATCH --mem-per-cpu=9G
#SBATCH -o log/syscomb-%j.out
#SBATCH -e log/syscomb-%j.out


set -euo pipefail

echo "$0 $@"  # Print the command line for logging

scoring_opts="--min-lmwt 6"
cmd="slurm.pl --mem 30G"
latweights=""

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;



exp=$1
shift;
data=$1
shift;

mkdir $exp

for dir in $*; do
    echo I got $dir 
done

for dir in $*; do
    if [ -f $dir/all_words_pre ]; then 
    cat $dir/all_words_pre >> $exp/all_words
    elif [ -f $dir/all_words ]; then 
    cat $dir/all_words >> $exp/all_words
    else
    cat $dir/all_words_10 >> $exp/all_words
    fi
    echo $dir >> $exp/systems
done

sort -u  $exp/all_words <(cut -f1 -d' ' data/default_lang/words.txt | grep -v "<eps>" | grep -v "<s>" | grep -v "</s>" | grep -v "^#") >  $exp/vocab
common/make_dict.sh $exp/vocab $exp/dict

utils/prepare_lang.sh --phone-symbol-table data/default_lang/phones.txt $exp/dict "<UNK>" $exp/lang/local $exp/lang

declare -a LATS

i=0
for dir in $*; do

     old_lang=$(grep -o -E "^.*decode" <<< $dir | sed "s/decode/graph_/")$(grep -o -E "(word|char|morf).*(f1|aff|pre|suf|wma)" <<< $dir)_small
     echo $old_lang
     if [ ! -f $old_lang/words.txt ]; then
     old_lang=$(grep -o -E "^.*decode" <<< $dir | sed "s/decode/graph_/")$(grep -o -E "(word|char|morf).*(f1|aff|pre|suf|wma)" <<< $dir)_domainmix1
     fi
     
     common/to_word_lat_impr.sh --cmd "$cmd" --scoring-opts "$scoring_opts" $data $old_lang $exp/lang $dir $exp/sys$i
     LATS+=("ark:gunzip -c $exp/sys$i/lat.1.gz|")
     i=$(( $i + 1 )) 
done

mkdir $exp/comb_sys

lattice-combine --lat-weights=$latweights "${LATS[@]}"  "ark:|gzip -c > $exp/comb_sys/lat.1.gz"


local/score.sh --decode-mbr true --cmd "$cmd" $scoring_opts $data $exp/lang $exp/comb_sys

