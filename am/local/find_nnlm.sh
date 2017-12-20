#!/bin/bash

for n in $(find /scratch/work/gangirs1/asru2017/experiments -name nnlm.h5); do

mark=$(grep -o -E "wma|f1|suf|pre|aff" <<< $n)
if grep -q word <<< $n; then
model=word
elif grep -q m0 <<< $n; then
model=$(grep -o -E "m0.*(types|tokens)" <<< $n | sed "s/m/morfessor_f2_a/")
else
model=chars
fi

domain=""
if grep -q parl <<< $n; then
domain="domain_"
fi

lmsuf=""
if grep -q 10/ <<< $n; then
lmsuf=10
fi

if grep -q 10_ <<< $n; then
lmsuf=10
fi

trainfile=$(ls -1 $(dirname $n)/train-*.log | sort | tail -n1)
echo $mark $model $n $trainfile
if tail -n1 $trainfile | grep -q "train_theanolm finished"; then
echo Finished
echo data/lm${lmsuf}/${model}_$mark/${domain}rescore
if [ ! -e data/lm${lmsuf}/${model}_$mark/${domain}rescore/nnlm.h5.orig ]; then
ln -s $n  data/lm${lmsuf}/${model}_$mark/${domain}rescore/nnlm.h5.orig
fi

if [ -f  data/lm${lmsuf}/${model}_$mark/${domain}rescore/nnlm.h5 ] &&  [ data/lm${lmsuf}/${model}_$mark/${domain}rescore/nnlm.h5.orig -nt data/lm${lmsuf}/${model}_$mark/${domain}rescore/nnlm.h5 ]; then
   echo "WRONG!"
   exit 1
fi

if [ ! -f data/lm${lmsuf}/${model}_$mark/${domain}rescore/nnlm.h5 ]; then
cp data/lm${lmsuf}/${model}_$mark/${domain}rescore/nnlm.h5.orig data/lm${lmsuf}/${model}_$mark/${domain}rescore/nnlm.h5
fi

else
echo NOT 
fi
done
