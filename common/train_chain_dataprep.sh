#!/bin/bash

echo "$0 $@"  # Print the command line for logging
export LC_ALL=C

set -euo pipefail
IFS=$'\n\t'

train_set=
gmm=

speed_perturb=true
vol_perturb=true

mfcc_conf=mfcc_hires

min_seg_len=0.0

ivec_dim=512
data_lang=data/lang

[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

if [ $# != 1 ]; then
   echo "usage: train_chain_dataprep.sh config_name"
   exit 1;
fi

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

config_name=$1

. common/slurm_dep_graph.sh

JOB_PREFIX=$(cat id)_

. definitions/chain/dataprep/$config_name

dir=exp/chain/dataprep/$config_name
SDG_LOG_DIR=$dir/log
mkdir -p $dir/{data,ali,lats}
data=$dir/data

mkdir -p $data/orig

if [ ! -f $data/orig/train ]; then ln -rs $train_set $data/orig/train; fi
#if [ ! -f $data/orig/dev ]; then ln -rs data/dev $data/orig/dev; fi
#if [ ! -f $data/orig/test ]; then ln -rs data/test $data/orig/test; fi

#for set in "dev" "test"; do
#  job copy_h_$set 1 4 NONE -- utils/copy_data_dir.sh $data/orig/$set $data/$set
#  job val1_$set 1 4 LAST -- utils/validate_data_dir.sh --no-feats $data/$set
#done

job utt2dur_train 1 4 NONE -- utils/data/get_utt2dur.sh $data/orig/train

if [ $speed_perturb ]; then
  job speed_perturb_train 2 4 LAST -- utils/data/perturb_data_dir_speed_3way.sh $data/orig/train $data/train
else
  job copy_h_train 2 4 LAST -- utils/copy_data_dir.sh $data/orig/train $data/train
fi

if [ $vol_perturb ]; then
  job vol_perturb_train 2 4 LAST -- utils/data/perturb_data_dir_volume.sh $data/train
fi

job copy_l_train 2 4 LAST -- utils/copy_data_dir.sh $data/train $data/train_lores
job val1_train 2 4 LAST   -- utils/validate_data_dir.sh --no-text --no-feats $data/train

numjobs=$(( $(wc -l < $data/orig/train/spk2utt) / 10 ))
job mfcc_lores_train 2 4 copy_l_train -- steps/make_mfcc.sh --cmd "$mfcc_cmd" --nj ${numjobs} $data/train_lores
job cmvn_lores_train 2 4 LAST         -- steps/compute_cmvn_stats.sh $data/train_lores
job fix_lores_train 4 4 LAST          -- utils/fix_data_dir.sh $data/train_lores
job val_lores_train 2 4 LAST          -- utils/validate_data_dir.sh $data/train_lores

for set in "train"; do
  numjobs=$(( $(wc -l < $data/orig/$set/spk2utt) / 3 ))
  job mfcc_hires_$set 2 4 val1_$set -- steps/make_mfcc.sh --mfcc-config conf/${mfcc_conf}.conf --cmd "$mfcc_cmd" --nj ${numjobs} $data/$set
  job cmvn_hires_$set 2 4 LAST      -- steps/compute_cmvn_stats.sh $data/$set
  job fix_hires_$set 4 4 LAST       -- utils/fix_data_dir.sh $data/$set
  job val_data_$set 2 4 LAST        -- utils/validate_data_dir.sh $data/$set
done

numjobs=100 #$(wc -l < $data/orig/train/spk2utt)
job ali 2 1  val_lores_train -- steps/align_fmllr.sh --nj $numjobs --cmd "slurm.pl --mem 2G" $data/train_lores $data_lang $gmm $dir/ali
job lats 2 1 val_lores_train -- steps/align_fmllr_lats.sh --nj $(($numjobs*2)) --cmd "slurm.pl --mem 2G" $data/train_lores $data_lang $gmm $dir/lats

tcdir=$data/train
tcsince=val_data_train
if [[ $min_seg_len > 0.0 ]]; then
job comb_segments 3 1 val_data_train -- utils/data/combine_short_segments.sh $data/train $min_seg_len $data/train_comb
#job cmvn_comb 3 1 LAST               -- <(echo -e "#!/bin/bash\ncp $data/train/cmvn.scp $data/train_comb/cmvn.scp") 
job cmvn_comb 2 4 LAST      -- steps/compute_cmvn_stats.sh $data/train_comb
job val_data_train_comb 3 1 LAST     -- utils/validate_data_dir.sh --no-wav $data/train_comb
tcdir=$data/train_comb
tcsince=val_data_train_comb
fi

#IVECTOR STUFF
if [[ $ivec_dim > 0 ]]; then

ivec=$dir/ivec
mkdir -p $ivec/data

job max2_train 3 1 $tcsince              -- utils/data/modify_speaker_info.sh --utts-per-spk-max 2 $tcdir $ivec/data/train_max2

job get_orig_subset 3 1 val_data_train -- utils/data/subset_data_dir.sh --utt-list $data/orig/train/feats.scp $data/train $ivec/data/train
job validate_feat_count 3 1 LAST       -- <(echo -e "#!/bin/bash\nif [ \$(wc -l < $data/orig/train/feats.scp) != \$(wc -l < $ivec/data/train/feats.scp) ]; then exit 1; fi")


mkdir -p $ivec/in_ali

#numjobs=$(wc -l < $data/orig/train/spk2utt)
numjobs=20
job ali_orig 4 4 LAST -- steps/align_fmllr.sh --nj $numjobs --cmd "slurm.pl --mem 4G" $data/orig/train $data_lang $gmm $ivec/in_ali

numjobs=20
SLURM_EXTRA_ARGS="-c ${numjobs}"
mkdir -p $ivec/tri5
job train_lda_mllt_iv 4 4 LAST \
 -- steps/train_lda_mllt.sh --cmd "$train_cmd" --num-iters 7 --mllt-iters "2 4 6" \
                            --splice-opts "--left-context=3 --right-context=3" \
                            3000 10000 $ivec/data/train $data_lang \
                            $ivec/in_ali $ivec/tri5

SLURM_EXTRA_ARGS=""
mkdir -p $ivec/diag_ubm
job diag_ubm 4 24 LAST \
 -- steps/online/nnet2/train_diag_ubm.sh --cmd "slurm.pl --mem 4G" --nj $numjobs \
    --num-frames 700000 --num-threads 20 $ivec/data/train $ivec_dim $ivec/tri5 $ivec/diag_ubm

job iv_extractor 8 24 LAST \
  -- steps/online/nnet2/train_ivector_extractor.sh --cmd "slurm.pl --mem 4G" --nj $numjobs \
    $ivec/data/train $ivec/diag_ubm $ivec/extractor

SLURM_EXTRA_ARGS="-c ${numjobs}"
job iv_train 4 4 iv_extractor,max2_train \
 -- steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $numjobs \
                                                  $ivec/data/train_max2 $ivec/extractor \
                                                  $ivec/ivectors_train
#numjobs=5

#SLURM_EXTRA_ARGS="-c ${numjobs}"
#for set in "dev" "test"; do
#  job iv_${set} 4 4 iv_extractor,val_data_${set} \
#   -- steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $numjobs \
#                                                  $data/$set $ivec/extractor \
#                                                  $ivec/ivectors_$set
#done

fi

