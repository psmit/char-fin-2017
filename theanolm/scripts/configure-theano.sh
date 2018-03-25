#!/bin/bash -e
#
# Tell Theano to use as the GPUs specified by $DEVICES. Also enables OpenMP. Not
# sure if that helps anything with GPU.

source activate theano
export MKL_THREADING_LAYER=GNU
        declare -a DEVICES=(cuda0)
        RUN_GPU='srun --gres=gpu:1'
#fi

export OMP_NUM_THREADS=1



declare -a devices=("${DEVICES[@]:-cuda0}")
declare -a contexts
for i in "${!devices[@]}"
do
	contexts+=("dev${i}->${devices[${i}]}")
done
THEANO_FLAGS="floatX=float32,device=${devices[0]}"
if [ ${#devices[@]} -gt 1 ]
then
	THEANO_FLAGS=$(IFS=,; echo "${THEANO_FLAGS},contexts=${contexts[*]}")
fi
THEANO_FLAGS="${THEANO_FLAGS},base_compiledir=${TMPDIR}/theano"
THEANO_FLAGS="${THEANO_FLAGS},exception_verbosity=high"
[ -n "${DEBUG}" ] && THEANO_FLAGS="${THEANO_FLAGS},optimizer=None"
THEANO_FLAGS="${THEANO_FLAGS},nvcc.fastmath=True"
#[ -d /usr/lib64 ] && THEANO_FLAGS="${THEANO_FLAGS},openmp=True,blas.ldflags=-L/usr/lib64 -lopenblaso"
export THEANO_FLAGS



export LD_LIBRARY_PATH=/home/user/path_to_CUDNN_folder/lib64:$LD_LIBRARY_PATH
export CPATH=$CUDNN_PATH/include:$CPATH
export LIBRARY_PATH=$CUDNN_PATH/lib64:$LIBRARY_PATH



#rm -rf "${TMPDIR}/theano"
