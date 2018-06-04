#!/bin/bash -e

ARCHITECTURE="class+proj500+lstm1500+htanh1500x4+dropout0.2+softmax"
SEQUENCE_LENGTH="40"
BATCH_SIZE="64"
TRAINING_STRATEGY="local-mean"
OPTIMIZATION_METHOD="adagrad"
STOPPING_CRITERION="no-improvement"
VALIDATION_FREQ="2"
PATIENCE="2"
LEARNING_RATE="0.1"
GRADIENT_DECAY_RATE=""
EPSILON=""
MAX_GRADIENT_NORM="5"
#UNK_PENALTY="-5"
IGNORE_UNK="1"
MAX_TOKENS_PER_NODE="62"
BEAM="650"
RECOMBINATION_ORDER="22"
DEBUG=""
#VOCAB_SIZE="200000"
NUM_NOISE_SAMPLES="20"
CLASSES="/wrk/psmit/chars-fin-2017/theanolm/experiments/exchange/n=2000_mf2_0.1_aff/exchange.temp23.classes"
#CLASSES="/scratch/work/gangirs1/asru2017/classes/n=2000_morfessor_f2_a0.005_tokens_kie_wma/exchange.classes"
