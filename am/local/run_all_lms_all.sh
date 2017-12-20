#!/bin/bash


#common/run_all_lms.sh --iter 1000 --dataset yle-dev exp/chain/model/old 10
#common/run_all_lms.sh --iter 1000 --dataset yle-dev exp/chain/model/old "" 
common/run_all_lms.sh --iter 1000 --dataset yle-dev-new exp/chain/model/old 10
common/run_all_lms.sh --iter 1000 --dataset yle-dev-new exp/chain/model/old "" 


#local/run_all_lms.sh --iter 1000 --dataset parl-dev-unseen exp/chain/model/old 10
#local/run_all_lms.sh --iter 1000 --dataset parl-dev-unseen exp/chain/model/old "" 


#local/run_all_lms.sh --iter 1000 --dataset parl-dev-seen exp/chain/model/old 10
#local/run_all_lms.sh --iter 1000 --dataset parl-dev-seen exp/chain/model/old "" 


common/run_all_lms.sh --iter 1000 --dataset parl-dev exp/chain/model/old 10
common/run_all_lms.sh --iter 1000 --dataset parl-dev exp/chain/model/old "" 


#common/run_all_lms.sh --iter 1150 --dataset yle-dev exp/chain/model/all_tdnn_blstm_9_a 10
#common/run_all_lms.sh --iter 1150 --dataset yle-dev exp/chain/model/all_tdnn_blstm_9_a "" 
common/run_all_lms.sh --iter 1150 --dataset yle-dev-new exp/chain/model/all_tdnn_blstm_9_a 10
common/run_all_lms.sh --iter 1150 --dataset yle-dev-new exp/chain/model/all_tdnn_blstm_9_a "" 
common/run_all_lms.sh --iter 1150 --dataset parl-dev exp/chain/model/all_tdnn_blstm_9_a 10
common/run_all_lms.sh --iter 1150 --dataset parl-dev exp/chain/model/all_tdnn_blstm_9_a ""
