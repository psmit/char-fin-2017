#!/bin/bash
#SBATCH -n 1
#SBATCH --cpus-per-task=10
#SBATCH -N 1
#SBATCH --mem-per-cpu 4G

set -euo pipefail

# Begin configuration section.
cmd="run.pl --max-jobs-run 9"
scoring_opts=
start=1
end=9
step=1
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

if [ $# -ne 5 ]; then
  echo "Usage: common/interpolate_2lattices.sh [options] <data> <lang-dir|graph-dir> <lat-dir1> <lat-dir2> <decode-dir-out>"
  echo " e.g.: steps/decode_combine.sh data/lang data/test exp/dir1/decode exp/dir2/decode exp/combine_1_2/decode"
  echo "main options (for others, see top of script file)"
  echo "  --cmd <cmd>                              # Command to run in parallel with"
  exit 1;
fi

data=$1
lang=$2
srcdir1=$3
srcdir2=$4
dir=$5

mkdir -p $dir


for i in $(seq $start $step $end); do
  if [ ! -f $dir/i0.$i/scoring_kaldi/best_wer ]; then
  steps/decode_combine.sh --scoring-opts "$scoring_opts" --cmd "$cmd" --weight1 0.$i $data $lang $srcdir1 $srcdir2 $dir/i0.$i 
  fi
done
wait
common/select_best.sh $dir
