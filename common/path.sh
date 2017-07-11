#!/bin/bash

export PYTHONIOENCODING='utf-8'
export PATH="$PWD/utils:$PWD:$PATH"

module load openfstpy kaldi/2017.06.28-c12c1b8-GCC-5.4.0-mkl phonetisaurus anaconda3 anaconda2 srilm mitlm Morfessor sph2pipe variKN m2m-aligner openfst/1.6.2-GCC-5.4.0

module list

