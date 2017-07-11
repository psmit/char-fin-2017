#!/bin/bash

echo "$0 $@"  # Print the command line for logging
export LC_ALL=C

[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

if [ $# != 1 ]; then
   echo "usage: train_am.sh prefix"
   exit 1;
fi

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

prefix=${1}_
prefi=$1

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

#rm -Rf data mfcc
mkdir -p data


#lex_name="lexicon"
#if [ -f definitions/lexicon ]; then
#  lex_name=$(cat definitions/lexicon)
#fi
#ln -s ../data-prep/${lex_name}/ data/lexicon

job make_subset 1 1 NONE -- common/data_subset.sh $prefi

job make_lex 1 4 make_subset -- common/make_dict.sh data/${prefix}train/vocab data/${prefix}dict
job make_lang 1 4 make_lex -- utils/prepare_lang.sh --position-dependent-phones true data/${prefix}dict "<UNK>" data/${prefix}lang/local data/${prefix}lang

mfccdir=mfcc
numjobs=100

. definitions/$prefi/best_model

# Extract low-res standard features
mkdir -p mfcc
command -v lfs > /dev/null && lfs setstripe -c 6 $mfccdir

for set in "${prefix}train"; do
 job mfcc_$set 1 4 make_subset -- steps/make_mfcc.sh --cmd "$mfcc_cmd" --nj ${numjobs} data/${set} exp/make_mfcc/${set} ${mfccdir}
 job cmvn_$set 1 4 LAST      -- steps/compute_cmvn_stats.sh data/${set} exp/make_mfcc/${set} ${mfccdir}
 job fix_data_$set 4 4 LAST  -- utils/fix_data_dir.sh data/${set}
 job val_data_$set 1 4 LAST  -- utils/validate_data_dir.sh data/${set}
 job utt2dur_$set 1 4 LAST   -- utils/data/get_utt2dur.sh data/${set}
done

# Make short dir
numjobs=10
job subset_10kshort 1 4 utt2dur_${prefix}train \
 -- utils/subset_data_dir.sh --shortest data/${prefix}train ${sub_size:-10000} data/${prefix}train_10kshort

# Train basic iterations
SLURM_EXTRA_ARGS="-c ${numjobs}"
job tra_mono 1 4 subset_10kshort,make_lang \
 -- steps/train_mono.sh --boost-silence 1.25 --nj ${numjobs} --cmd "$train_cmd" data/${prefix}train_10kshort data/${prefix}lang exp/${prefix}mono

job ali_mono 1 4 tra_mono,val_data_${prefix}train \
 -- steps/align_si.sh --boost-silence 1.25 --nj ${numjobs} --cmd "$train_cmd" data/${prefix}train data/${prefix}lang exp/${prefix}mono exp/${prefix}mono_ali

job tra_tri1 1 4 LAST \
 -- steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" $tri1_leaves $tri1_gauss data/${prefix}train data/${prefix}lang exp/${prefix}mono_ali exp/${prefix}tri1

job ali_tri1 1 4 LAST \
 -- steps/align_si.sh --nj ${numjobs} --cmd "$train_cmd" data/${prefix}train data/${prefix}lang exp/${prefix}tri1 exp/${prefix}tri1_ali

job tra_tri2 1 4 LAST \
 -- steps/train_lda_mllt.sh --cmd "$train_cmd" --splice-opts "--left-context=3 --right-context=3" $tri2_leaves $tri2_gauss data/${prefix}train data/${prefix}lang exp/${prefix}tri1_ali exp/${prefix}tri2

job ali_tri2 1 4 LAST \
 -- steps/align_si.sh  --nj ${numjobs} --cmd "$train_cmd"  data/${prefix}train data/${prefix}lang exp/${prefix}tri2 exp/${prefix}tri2_ali

job tra_tri3 1 4 LAST \
 -- steps/train_sat.sh --cmd "$train_cmd" $tri3_leaves $tri3_gauss data/${prefix}train data/${prefix}lang exp/${prefix}tri2_ali exp/${prefix}tri3

job ali_tri3 1 4 LAST \
 -- steps/align_fmllr.sh  --nj ${numjobs} --cmd "$train_cmd"  data/${prefix}train data/${prefix}lang exp/${prefix}tri3 exp/${prefix}tri3_ali

SLURM_EXTRA_ARGS=""
# Create a cleaned version of the model, which is supposed to be better for
job clean 2 4 tra_tri3 \
 -- steps/cleanup/clean_and_segment_data.sh --nj 150 --cmd "slurm.pl --mem 2G" data/${prefix}train data/${prefix}lang exp/${prefix}tri3 exp/${prefix}tri3_cleaned_work data/${prefix}train_cleaned

SLURM_EXTRA_ARGS="-c ${numjobs}"
job ali_tri3_cleaned 2 4 LAST \
 -- steps/align_fmllr.sh --nj ${numjobs} --cmd "$train_cmd" data/${prefix}train_cleaned data/${prefix}lang exp/${prefix}tri3 exp/${prefix}tri3_ali_cleaned

job tra_tri3_cleaned 2 4 LAST \
 -- steps/train_sat.sh --cmd "$train_cmd" $tri3_leaves $tri3_gauss data/${prefix}train_cleaned data/${prefix}lang exp/${prefix}tri3_ali_cleaned exp/${prefix}tri3_cleaned



