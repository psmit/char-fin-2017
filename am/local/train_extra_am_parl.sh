#!/bin/bash

echo "$0 $@"  # Print the command line for logging
export LC_ALL=C


[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

if [ $# != 0 ]; then
   echo "usage: train_am.sh"
   exit 1;
fi

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

train_cmd="srun run.pl"
base_cmd=$train_cmd
decode_cmd=$train_cmd

. common/slurm_dep_graph.sh

JOB_PREFIX=$(cat id)_

function error_exit {
    echo "$1" >&2
    exit "${2:-1}"
}

if [ ! -d "data-prep" ]; then
 error_exit "The directory data-prep needs to exist. Run local/data_prep.sh"
fi

job make_lex 1 4 make_subset -- common/make_dict.sh data/parl-train-unfiltered/vocab data/parl_dict_all
job make_lang 4 4 make_lex -- utils/prepare_lang.sh --position-dependent-phones true data/parl_dict_all "<UNK>" data/parl_lang_all/local data/parl_lang_all


mfccdir=mfcc
numjobs=400

. definitions/parl/best_model

set=parl-train-unfiltered
 job mfcc_$set 1 4 NONE -- steps/make_mfcc.sh --cmd "$mfcc_cmd" --write-utt2num-frames true --nj ${numjobs} data/${set} exp/make_mfcc/${set} ${mfccdir}
 job cmvn_$set 1 4 LAST      -- steps/compute_cmvn_stats.sh data/${set} exp/make_mfcc/${set} ${mfccdir}
 job fix_data_$set 4 4 LAST  -- utils/fix_data_dir.sh data/${set}
 job val_data_$set 1 4 LAST  -- utils/validate_data_dir.sh data/${set}
 job utt2dur_$set 1 4 LAST   -- utils/data/get_utt2dur.sh data/${set}

for set in "parl-train-400-60min" "parl-train-400"; do
job cp 1 1 utt2dur_parl-train-unfiltered -- <(echo -e "#!/bin/bash\ncp data/parl-train-unfiltered/feats.scp data/${set}/")
job cmvn_$set 1 4 LAST      -- steps/compute_cmvn_stats.sh data/${set} exp/make_mfcc/${set} ${mfccdir}
job fix_data_$set 4 4 LAST  -- utils/fix_data_dir.sh data/${set}
job val_data_$set 1 4 LAST  -- utils/validate_data_dir.sh data/${set}
job utt2dur_$set 1 4 LAST   -- utils/data/get_utt2dur.sh data/${set}
done




###############################################################
numjobs=20
SLURM_EXTRA_ARGS="-c ${numjobs}"

job ali_tri3_60m 1 4 val_data_parl-train-400-60min,make_lang \
 -- steps/align_fmllr.sh  --nj ${numjobs} --cmd "$train_cmd"  data/parl-train-400-60min data/parl_lang_all exp/parl_tri3 exp/parl_tri3_ali_60min

job tra_tri4 2 4 LAST \
 -- steps/train_sat.sh --cmd "$train_cmd" $tri4_leaves $tri4_gauss data/parl-train-400-60min data/parl_lang_all exp/parl_tri3_ali_60min exp/parl_tri4

job ali_tri4 1 4 LAST \
 -- steps/align_fmllr.sh  --nj ${numjobs} --cmd "$train_cmd"  data/parl-train-400-60min data/parl_lang_all exp/parl_tri4 exp/parl_tri4_ali

job ali_tri4_400 1 4 tra_tri4,val_data_parl-train-400 \
 -- steps/align_fmllr.sh  --nj ${numjobs} --cmd "$train_cmd"  data/parl-train-400 data/parl_lang_all exp/parl_tri4 exp/parl_tri4_ali_400


job tra_tri5 2 4 LAST \
 -- steps/train_sat.sh --cmd "$train_cmd" $tri5_leaves $tri5_gauss data/parl-train-400 data/parl_lang_all exp/parl_tri4_ali_400 exp/parl_tri5

job ali_tri5 1 4 LAST \
 -- steps/align_fmllr.sh  --nj ${numjobs} --cmd "$train_cmd"  data/parl-train-400 data/parl_lang_all exp/parl_tri5 exp/parl_tri5_ali

job ali_tri5_all 1 4 tra_tri5,val_data_parl-train-unfiltered \
 -- steps/align_fmllr.sh  --nj ${numjobs} --cmd "$train_cmd"  data/parl-train-unfiltered data/parl_lang_all exp/parl_tri5 exp/parl_tri5_ali_unfiltered

SLURM_EXTRA_ARGS=""
job clean_60m 2 24 tra_tri4 \
 -- steps/cleanup/clean_and_segment_data.sh --nj 300 --cmd "slurm.pl --mem 2G" data/parl-train-400-60min data/parl_lang_all exp/parl_tri4 exp/parl_tri4_60min_cleaned_work data/parl-train-400-60min_cleaned

job clean_400 4 24 tra_tri5 \
 -- steps/cleanup/clean_and_segment_data.sh --nj 300 --cmd "slurm.pl --mem 2G" data/parl-train-400 data/parl_lang_all exp/parl_tri5 exp/parl_tri5_400_cleaned_work data/parl-train-400_cleaned

job clean_all 4 24 tra_tri5 \
 -- steps/cleanup/clean_and_segment_data.sh --nj 300 --cmd "slurm.pl --mem 2G" data/parl-train-unfiltered data/parl_lang_all exp/parl_tri5 exp/parl_tri5_all_cleaned_work data/parl-train-unfiltered_cleaned

SLURM_EXTRA_ARGS="-c ${numjobs}"
job ali_tri4_2h_cleaned 2 4 clean_60m \
 -- steps/align_fmllr.sh --nj ${numjobs} --cmd "$train_cmd" data/parl-train-400-60min_cleaned data/parl_lang_all exp/parl_tri4 exp/parl_tri4_ali_60min_cleaned

job tra_tri4_2h_cleaned 2 4 LAST \
 -- steps/train_sat.sh --cmd "$train_cmd" $tri4_leaves $tri4_gauss data/parl-train-400-60min_cleaned data/parl_lang_all exp/parl_tri4_ali_60min_cleaned exp/parl_tri4_60min_cleaned

job ali_tri5_accepted_cleaned 2 4 clean_400 \
 -- steps/align_fmllr.sh --nj ${numjobs} --cmd "$train_cmd" data/parl-train-400_cleaned data/parl_lang_all exp/parl_tri5 exp/parl_tri5_ali_400_cleaned

job tra_tri5_accepted_cleaned 2 4 LAST \
 -- steps/train_sat.sh --cmd "$train_cmd" $tri5_leaves $tri5_gauss data/parl-train-400_cleaned data/parl_lang_all exp/parl_tri5_ali_400_cleaned exp/parl_tri5_400_cleaned

job ali_tri5_all_cleaned 2 4 clean_all \
 -- steps/align_fmllr.sh --nj ${numjobs} --cmd "$train_cmd" data/parl-train-unfiltered_cleaned data/parl_lang_all exp/parl_tri5 exp/parl_tri5_ali_all_cleaned

job tra_tri5_all_cleaned 2 4 LAST \
 -- steps/train_sat.sh --cmd "$train_cmd" $tri5_leaves $tri5_gauss data/parl-train-unfiltered_cleaned data/parl_lang_all exp/parl_tri5_ali_all_cleaned exp/parl_tri5_all_cleaned
