#!/bin/bash

set -e -o pipefail

# Begin configuration section.
cmd=run.pl
skip_scoring=false
self_loop_scale=0.1

lmscale=7
beam=6

scoring_opts=

theanolm_beam=650
theanolm_maxtokens=200
theanolm_recombination=20
# End configuration section.

echo "$0 $@"  # Print the command line for logging

. ./utils/parse_options.sh

if [ $# != 5 ]; then
   echo "Do theanolm rescoring of lattices (remove old LM, add new LM)"
   echo "Usage: steps/lmrescore_theanolm.sh [options] <old-lang-dir> <new-lang-dir> <data-dir> <input-decode-dir> <output-decode-dir>"
   echo "options: [--cmd (run.pl|queue.pl [queue opts])]"
   exit 1;
fi

[ -f path.sh ] && . ./path.sh;

source activate theanolm
oldlang=$1
newlang=$2
data=$3
indir=$4
outdir=$5

oldlm=$oldlang/G.carpa
newlm=$newlang/nnlm.h5
! cmp $oldlang/words.txt $newlang/words.txt && echo "Warning: vocabularies may be incompatible."
[ ! -f $oldlm ] && echo Missing file $oldlm && exit 1;
[ ! -f $newlm ] && echo Missing file $newlm && exit 1;
! ls $indir/lat.*.gz >/dev/null && echo "No lattices input directory $indir" && exit 1;

if ! cmp -s $oldlang/words.txt $newlang/words.txt; then
  echo "$0: $oldlang/words.txt and $newlang/words.txt differ: make sure you know what you are doing.";
fi

mkdir -p $outdir/log

phi=`grep -w '#0' $newlang/words.txt | awk '{print $2}'`

# we have to prepare $outdir/Ldet.fst: determinized
# lexicon (determinized on phones), with disambig syms removed.
# take L_disambig.fst; get rid of transition with "#0 #0" on it; determinize
# with epsilon removal; remove disambiguation symbols.
#fstprint $newlang/L_disambig.fst | awk '{if($4 != '$phi'){print;}}' | fstcompile | \
#  fstdeterminizestar | fstrmsymbols $newlang/phones/disambig.int >$outdir/Ldet.fst || exit 1;

nj=`cat $indir/num_jobs` || exit 1;
echo "$nj" > $outdir/num_jobs


mdl=`dirname $indir`/final.mdl
[ ! -f $mdl ] && echo No such model $mdl && exit 1;
[[ -f `dirname $indir`/frame_subsampling_factor && "$self_loop_scale" == 0.1 ]] &&  echo "$0: WARNING: chain models need '--self-loop-scale 1.0'";

$cmd JOB=1:$nj $outdir/log/theanolm.JOB.log \
      gunzip -c $indir/lat.JOB.gz \| \
      lattice-prune --inv-acoustic-scale=$lmscale --beam=$beam ark:- ark:- \| \
      lattice-lmrescore-const-arpa --lm-scale=-1.0 ark:- "$oldlm" ark,t:- \| \
      theanolm rescore --log-file $outdir/log/theano_rescore.JOB.log --log-level debug $newlm - $oldlang/words.txt - --lm-scale $lmscale --beam $theanolm_beam --max-tokens-per-node $theanolm_maxtokens --recombination-order $theanolm_recombination \| \
      tee $outdir/lat.theanolm.JOB \| \
      lattice-minimize ark:- ark:- \| \
      gzip -c \>$outdir/lat.JOB.gz  || exit 1;


      #lattice-add-trans-probs --transition-scale=1.0 --self-loop-scale=$self_loop_scale $mdl ark:- ark,t:- \| \

if ! $skip_scoring ; then
  [ ! -x local/score.sh ] && \
    echo "Not scoring because local/score.sh does not exist or not executable." && exit 1;
  local/score.sh --cmd "$cmd" $scoring_opts $data $newlang $outdir
else
  echo "Not scoring because requested so..."
fi

exit 0;

