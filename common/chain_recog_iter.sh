#!/bin/bash
#SBATCH -p coin,short-ivb,short-wsm,short-hsw,batch-hsw,batch-wsm,batch-ivb
#SBATCH -t 3:00:00
#SBATCH -n 1
#SBATCH --cpus-per-task=20
#SBATCH -N 1
#SBATCH --mem-per-cpu=3G
#SBATCH -o log/recognize-%j.out
#SBATCH -e log/recognize-%j.out

export LC_ALL=C

# Begin configuration section.
dataset=dev
skip_scoring=false
beam=15
iter=final
extra_flags=""
# End configuration options.

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

if [ $# -ne 1 ]; then
   echo "usage: common/recognize.sh model"
   echo "e.g.:  common/recognize.sh gr_tdnn_lstm_a"
   echo "main options (for others, see top of script file)"

   exit 1;
fi

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

am=$1
decode_flags="--post-decode-acwt 10.0 --acwt 1.0"
if [ -f $am/decode_flags ]; then
decode_flags="${decode_flags} $(cat $am/decode_flags)"
fi

dsname=$(basename $dataset)
extra=""
if [ "$dsname" != "dev" ]; then 
extra=_$dsname
fi
if [ "$iter" != "final" ]; then
extra=${iter}${extra}
fi
if [ ! -f ${am}/decode${extra}/wer_15_0.0 ]; then 
 steps/nnet3/decode.sh $extra_flags --iter $iter --beam $beam --skip-scoring $skip_scoring --cmd "run.pl --max-jobs-run 18" --nj 50 $decode_flags --scoring-opts "--min-lmwt 4 --max-lmwt 18" --online-ivector-dir ${am}/ivecs/ivectors_${dataset} ${am}/graph ${am}/feats/${dataset} ${am}/decode${extra}

fi

