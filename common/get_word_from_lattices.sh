#!/bin/bash
#SBATCH -p coin,short-ivb,short-wsm,short-hsw,batch-hsw,batch-wsm,batch-ivb
#SBATCH -t 3:00:00
#SBATCH -n 1
#SBATCH --cpus-per-task=4
#SBATCH -N 1
#SBATCH --mem-per-cpu=5G
#SBATCH -o log/word_lat-%j.out
#SBATCH -e log/word_lat-%j.out

set -euo pipefail

# Begin configuration section.
cmd="run.pl --max-jobs-run 4"
beam=10
ac=0.125
# End configuration section.

echo "$0 $@"  # Print the command line for logging

. ./utils/parse_options.sh

if [ $# != 2 ]; then
   echo "Get words from lattices"
   echo "Usage: common/get_word_from_lattices.sh <lang-dir> <decode_dir>"
   exit 1;
fi

[ -f path.sh ] && . ./path.sh;

lang=$1
dir=$2

nj=$(cat $dir/num_jobs)

if [ -f  $dir/word_mapper ]; then
exit 0
fi
$cmd JOB=1:$nj $dir/log/getwords_${beam}.JOB.log \
      gunzip -c $dir/lat.JOB.gz \| \
      lattice-determinize-pruned --beam=$beam --acoustic-scale=$ac ark:- ark:- \| \
      lattice-project ark:- ark,t:- \| \
      common/get_words_from_lat.py $lang/words.txt \> $dir/latwords_${beam}.JOB || exit 1;
       
#      lattice-prune --inv-acoustic-scale=$ac --beam=$beam ark:- ark:- \| \


sort -u $dir/latwords_${beam}.* | tee $dir/all_seqs_${beam} | utils/int2sym.pl $lang/words.txt | sed "s/+//g" | sed "s/ //g" > $dir/all_words_${beam}
paste -d" " $dir/all_words_${beam} $dir/all_seqs_${beam} > $dir/word_mapper_${beam}

