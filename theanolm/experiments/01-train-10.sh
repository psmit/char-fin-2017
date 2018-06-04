#!/bin/bash -e
#SBATCH --partition gpu
#SBATCH --time=3-00
#SBATCH --gres=gpu:p100:1
#SBATCH --mem=20G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=peter.smit@aalto.fi


WORK_DIR=/wrk/psmit/chars-fin-2017/theanolm/
EXPT_SCRIPT_DIR=`pwd`

data_dir="$WORK_DIR/data"
dset=$(basename $(dirname `pwd`))
declare -a TRAIN_FILES=("${data_dir}/$dset/kielipankki-10.train")
DEVEL_FILE="${data_dir}/$dset/kielipankki-10.dev"
EVAL_FILE="${data_dir}/$dset/kielipankki-10.dev"


source ../../../scripts/run-expt.sh "${0}"
source "${PROJECT_SCRIPT_DIR}/train-functions.sh"

#module purge
#module load srilm

#if [[ "$(uname -n)" = t40511* ]]
#then
#	module load Theano
#	export PYTHONPATH="${PYTHONPATH}:${HOME}/git/theanolm"
#	export PATH="${PATH}:${HOME}/git/theanolm/bin"
#else
#	module load CUDA
#	module load cudnn
#	module load TheanoLM-develop
#        module load libgpuarray
#source activate theano
#export MKL_THREADING_LAYER=GNU
        #declare -a DEVICES=(cuda0)
	#RUN_GPU='srun --gres=gpu:1'
#fi

#export OMP_NUM_THREADS=1

train_theanolm
