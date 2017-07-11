#!/bin/bash

. common/slurm_dep_graph.sh

dataset=dev
iter=final
run=false

[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

if [ $# -ne 2 ]; then
   echo "usage: common/recognize.sh am_model lmsel"
   echo "e.g.:  common/recognize.sh --dataset yle-dev exp/chain/model/tdnn"
   echo "main options (for others, see top of script file)"

   exit 1;
fi

am=$1
lmsel=$2

JOB_PREFIX=$(cat id)_

srun=$run

for model in $(ls -1 data/lm$lmsel ); do
#if echo $model | grep -v -q "word_f2"; then
#echo "skip $model"
#continue
#fi
run=$srun
prev=NONE
if $run || [ ! -f data/recog_langs/${model}${lmsel}_small/G.fst ]; then
    job process_lm_$model 30 1 NONE common/process_lm.sh $model "$lmsel"
    run=true
    prev=LAST
fi

if $run || [ ! -f $am/graph_${model}${lmsel}_small/HCLG.fst ];  then
    job mkgraph_$model 25 4 process_lm_$model -- utils/mkgraph.sh --self-loop-scale 1.0 data/recog_langs/${model}${lmsel}_small $am $am/graph_${model}${lmsel}_small
    run=true
    prev=LAST
fi

if $run || [ ! -f $am/graph_${model}${lmsel}_domain_small/HCLG.fst ];  then
    job mkgraph_domain_$model 45 4 process_lm_$model -- utils/mkgraph.sh --self-loop-scale 1.0 data/recog_langs/${model}${lmsel}_domain_small $am $am/graph_${model}${lmsel}_domain_small
    run=true
    prev=LAST
fi

dsname=$(basename $dataset)
extra=_$dsname
if [ "$iter" != "final" ]; then
extra=${iter}${extra}
fi

if $run || { [ ! -f $am/decode${extra}_${model}${lmsel}_small/scoring_kaldi/best_wer ]; }; then
   job recognize_$model 2 4 mkgraph_$model -- common/chain_recog.sh --dataset $dataset --iter $iter $am data/recog_langs/${model}${lmsel}_small
   run=true
fi


if $run || { [ ! -f $am/decode${extra}_${model}${lmsel}_domain_small/scoring_kaldi/best_wer ]; }; then
   job recognize_domain_$model 2 4 mkgraph_domain_$model -- common/chain_recog.sh --dataset $dataset --iter $iter $am data/recog_langs/${model}${lmsel}_domain_small
   run=true
fi

if [ -f data/lm${lmsel}/$model/rescore/arpa ]; then 

if [ ! -f data/recog_langs/$model${lmsel}_rescore/G.carpa ]; then
   job const_arpa_$model 50 4 process_lm_$model -- common/build_const_arpa_lm.sh data/lm${lmsel}/$model/rescore/arpa data/langs/${model}${lmsel} data/recog_langs/$model${lmsel}_rescore 
fi

if [ ! -f $am/decode${extra}_${model}${lmsel}_rescore/scoring_kaldi/best_wer ]; then
SLURM_EXTRA_ARGS="-c 10"
  job rescore_$model 8 4 const_arpa_$model,recognize_$model -- steps/lmrescore_const_arpa.sh --cmd "run.pl --max-jobs-run 19" --skip-scoring false --scoring-opts "--min-lmwt 4 --max-lmwt 18" data/recog_langs/${model}${lmsel}_small data/recog_langs/${model}${lmsel}_rescore ${am}/feats/${dsname} $am/decode${extra}_${model}${lmsel}_small $am/decode${extra}_${model}${lmsel}_rescore 
SLURM_EXTRA_ARGS=""
fi

fi


if [ -f data/lm${lmsel}/$model/rescore/no_arpa ]; then
   if [ ! -e $am/decode${extra}_${model}${lmsel}_rescore ]; then
       ln -rs $am/decode${extra}_${model}${lmsel}_small $am/decode${extra}_${model}${lmsel}_rescore
   fi
if [ ! -f data/recog_langs/$model${lmsel}_rescore/G.carpa ]; then
   job const_arpa_$model 50 4 process_lm_$model -- common/build_const_arpa_lm.sh data/lm${lmsel}/$model/small/arpa data/langs/${model}${lmsel} data/recog_langs/$model${lmsel}_rescore
   prev=LAST
fi

fi

if [ -f data/lm${lmsel}/$model/domain_rescore/arpa ]; then 

if [ ! -f data/recog_langs/$model${lmsel}_domain_rescore/G.carpa ]; then
   job const_arpa_domain_$model 40 4 process_lm_$model -- common/build_const_arpa_lm.sh data/lm${lmsel}/$model/domain_rescore/arpa data/langs/${model}${lmsel} data/recog_langs/$model${lmsel}_domain_rescore 
fi

if [ ! -f $am/decode${extra}_${model}${lmsel}_domain_rescore/scoring_kaldi/best_wer ]; then
SLURM_EXTRA_ARGS="-c 10"
  job rescore_domain_$model 2 4 const_arpa_domain_$model,recognize_domain_$model -- steps/lmrescore_const_arpa.sh --cmd "run.pl --max-jobs-run 19" --skip-scoring false --scoring-opts "--min-lmwt 4 --max-lmwt 18" data/recog_langs/${model}${lmsel}_domain_small data/recog_langs/${model}${lmsel}_domain_rescore ${am}/feats/${dsname} $am/decode${extra}_${model}${lmsel}_domain_small $am/decode${extra}_${model}${lmsel}_domain_rescore 
SLURM_EXTRA_ARGS=""
fi

fi

if [ -f data/lm${lmsel}/$model/domain_rescore/no_arpa ]; then
   if [ ! -e $am/decode${extra}_${model}${lmsel}_domain_rescore ]; then
       ln -rs $am/decode${extra}_${model}${lmsel}_domain_small $am/decode${extra}_${model}${lmsel}_domain_rescore
   fi
if [ ! -f data/recog_langs/$model${lmsel}_domain_rescore/G.carpa ]; then
   job const_arpa_domain_$model 40 4 process_lm_$model -- common/build_const_arpa_lm.sh data/lm${lmsel}/$model/domain_small/arpa data/langs/${model}${lmsel} data/recog_langs/$model${lmsel}_domain_rescore
   prev=LAST
fi

fi
#suf=big
#for i in $(seq 1 9); do

#if [ ! -f $am/decode${extra}_${model}_interp_${suf}/i0.${i}/scoring_mrwer/best_mrwer ] && [ ! -f $am/decode${extra}_${model}_interp_${suf}/i0.${i}/scoring_kaldi/best_wer ]; then

#SLURM_EXTRA_ARGS=" -c 8"
#job comb_${suf}_$i 3 4 $prev -- steps/decode_combine.sh --weight1 0.$i --scoring-opts "--min-lmwt 4" --cmd "run.pl --max-jobs-run 8" data/$dataset data/langs_gr/$model ${am}/decode${extra}_${model}  ${am}/decode${extra}_${model}_${suf} ${am}/decode${extra}_${model}_interp_$suf/i0.$i

#fi
#done



#SLURM_EXTRA_ARGS=""
#job best_${suf} 2 4 comb_${suf}_1,comb_${suf}_2,comb_${suf}_3,comb_${suf}_4,comb_${suf}_5,comb_${suf}_6,comb_${suf}_7,comb_${suf}_8,comb_${suf}_9 -- common/select_best.sh ${am}/decode${extra}_${model}_interp_$suf

#for suf in "egy" "domain"; do
#for i in $(seq 1 9); do

#if [ ! -f $am/decode${extra}_${model}_interp_${suf}/i0.${i}/scoring_mrwer/best_mrwer ] && [ ! -f $am/decode${extra}_${model}_interp_${suf}/i0.${i}/scoring_kaldi/best_wer ]; then

#SLURM_EXTRA_ARGS=" -c 8"
#job comb_${suf}_$i 3 4 best_big -- steps/decode_combine.sh --weight1 0.$i --scoring-opts "--min-lmwt 4" --cmd "run.pl --max-jobs-run 8" data/$dataset data/langs_gr/$model ${am}/decode${extra}_${model}  ${am}/decode${extra}_${model}_${suf} ${am}/decode${extra}_${model}_interp_$suf/i0.$i
#
#fi
#done
#SLURM_EXTRA_ARGS=""
#job best_${suf} 2 4 comb_${suf}_1,comb_${suf}_2,comb_${suf}_3,comb_${suf}_4,comb_${suf}_5,comb_${suf}_6,comb_${suf}_7,comb_${suf}_8,comb_${suf}_9 -- common/select_best.sh ${am}/decode${extra}_${model}_interp_$suf
#done


#continue
#if [ ! -f $am/decode${extra}_${model}_rnn/num_jobs ]; then
#  if [ -f data/lm/$model/rescore/nnlm.h5 ]; then
#    if [ ! -e data/recog_langs${lsuf}/$model/nnlm.h5 ]; then
#      ln -rs data/lm/$model/rescore/nnlm.h5 data/recog_langs${lsuf}/$model/nnlm.h5 

tlbeam=600
tlmaxtok=120
tlrecomb=20
mem=20
if [[ $model == word* ]]; then
tlbeam=500
tlmaxtok=100
tlrecomb=10
mem=40
fi

if [ ! -f $am/decode${extra}_${model}${lmsel}_rnn/num_jobs ]; then
  if [ -f data/lm$lmsel/$model/rescore/nnlm.h5 ]; then
    mkdir -p data/recog_langs/$model${lmsel}_rescore
    if [ ! -e data/recog_langs/$model${lmsel}_rescore/nnlm.h5 ]; then
      ln -rs data/lm$lmsel/$model/rescore/nnlm.h5 data/recog_langs/$model${lmsel}_rescore/nnlm.h5
    fi
    job rescore_rnn_$model 4 12 rescore_$model -- common/lmrescore_theanolm_b.sh --beam 8 --scoring-opts "--min-lmwt 4" --lmscale 8.0 --theanolm-beam $tlbeam --theanolm-recombination $tlrecomb --theanolm-maxtokens $tlmaxtok --cmd "slurm.pl --mem ${mem}G"  data/recog_langs/$model${lmsel}_rescore data/recog_langs/$model${lmsel}_rescore  data/$dataset $am/decode${extra}_${model}${lmsel}_rescore $am/decode${extra}_${model}${lmsel}_rnn
  fi
fi

if [ ! -e data/recog_langs/$model${lmsel}_rescore/nnlm.h5 ] && [ -e $am/decode${extra}_${model}${lmsel}_rnn/num_jobs ]; then
  echo "WARNING: $am/decode${extra}_${model}${lmsel}_rnn should be deleted"
fi
if [ ! -e data/recog_langs/$model${lmsel}_domain_rescore/nnlm.h5 ] && [ -e $am/decode${extra}_${model}${lmsel}_domain_rnn/num_jobs ]; then
  echo "WARNING: $am/decode${extra}_${model}${lmsel}_domain_rnn should be deleted"
fi
if [ -f $am/decode${extra}_${model}${lmsel}_rnn/scoring_kaldi/best_wer ]; then
  job interp 3 4 NONE -- common/interpolate_2lattices_simple.sh --start 3 --scoring-opts "--min-lmwt 4" data/$dataset data/recog_langs/${model}${lmsel}_rescore $am/decode${extra}_${model}${lmsel}_rescore $am/decode${extra}_${model}${lmsel}_rnn $am/decode${extra}_${model}${lmsel}_rnn_interp
fi

if [ ! -f $am/decode${extra}_${model}${lmsel}_domain_rnn/num_jobs ]; then
  if [ -f data/lm$lmsel/$model/domain_rescore/nnlm.h5 ]; then
    mkdir -p data/recog_langs/$model${lmsel}_domain_rescore
    if [ ! -e data/recog_langs/$model${lmsel}_domain_rescore/nnlm.h5 ]; then
      ln -rs data/lm$lmsel/$model/domain_rescore/nnlm.h5 data/recog_langs/$model${lmsel}_domain_rescore/nnlm.h5
    fi
    job rescore_rnn_domain_$model 4 12 rescore_domain_$model -- common/lmrescore_theanolm_b.sh --beam 8 --scoring-opts "--min-lmwt 4" --lmscale 8.0 --theanolm-beam $tlbeam --theanolm-recombination $tlrecomb --theanolm-maxtokens $tlmaxtok --cmd "slurm.pl --mem ${mem}G"  data/recog_langs/$model${lmsel}_domain_rescore data/recog_langs/$model${lmsel}_domain_rescore  data/$dataset $am/decode${extra}_${model}${lmsel}_domain_rescore $am/decode${extra}_${model}${lmsel}_domain_rnn
  fi
fi

if [ -f $am/decode${extra}_${model}${lmsel}_domain_rnn/scoring_kaldi/best_wer ]; then
  job interp 3 4 NONE -- common/interpolate_2lattices_simple.sh --start 3 --scoring-opts "--min-lmwt 4" data/$dataset data/recog_langs/${model}${lmsel}_domain_rescore $am/decode${extra}_${model}${lmsel}_domain_rescore $am/decode${extra}_${model}${lmsel}_domain_rnn $am/decode${extra}_${model}${lmsel}_domain_rnn_interp
fi
continue
#prev=LAST

if [ ! -f $am/decode${extra}_${model}_egymix1_rnn_bg/num_jobs ]; then
  if [ -f data/lm/$model/rescore/nnlm.h5 ]; then
    mkdir -p data/recog_langs${lsuf}/${model}_egymix1
    if [ ! -e data/recog_langs${lsuf}/${model}_egymix1/nnlm.h5 ]; then
      ln -rs data/lm/$model/rescore/nnlm.h5 data/recog_langs${lsuf}/${model}_egymix1/nnlm.h5 
    fi
    job rescore_rnn 4 12 $prev -- common/lmrescore_theanolm_b.sh --beam 8 --scoring-opts "--min-lmwt 4" --lmscale 8.0 --theanolm-beam $tlbeam --theanolm-recombination $tlrecomb --theanolm-maxtokens $tlmaxtok --cmd "slurm.pl --mem ${mem}G"  data/recog_langs${lsuf}/${model}_egymix2 data/recog_langs${lsuf}/${model}_egymix1 data/$dataset ${am}/decode${extra}_${model}_egymix1_egymix2 ${am}/decode${extra}_${model}_egymix1_rnn_bg
  fi
fi

if [ -f $am/decode${extra}_${model}_egymix1_rnn_bg/scoring_mrwer/best_mrwer ]; then # && [ ! -f ${am}/decode${extra}_${model}_egymix1_rnn_bg_interp/best/scoring_mrwer/best_mrwer ] ; then
  job interp 3 4 NONE -- common/interpolate_2lattices_simple.sh --start 3 --scoring-opts "--min-lmwt 4" data/$dataset data/recog_langs${lsuf}/${model}_egymix2 ${am}/decode${extra}_${model}_egymix1_egymix2 ${am}/decode${extra}_${model}_egymix1_rnn_bg ${am}/decode${extra}_${model}_egymix1_rnn_bg_interp
fi

if [ -f $am/decode${extra}_${model}_egymix1_rnn_egy/scoring_mrwer/best_mrwer ]; then # && [ ! -f ${am}/decode${extra}_${model}_egymix1_rnn_egy_interp/best/scoring_mrwer/best_mrwer ] ; then
  job interp 3 4 NONE -- common/interpolate_2lattices_simple.sh --start 3 --scoring-opts "--min-lmwt 4" data/$dataset data/recog_langs${lsuf}/${model}_egymix2 ${am}/decode${extra}_${model}_egymix1_egymix2 ${am}/decode${extra}_${model}_egymix1_rnn_egy ${am}/decode${extra}_${model}_egymix1_rnn_egy_interp
fi

done
