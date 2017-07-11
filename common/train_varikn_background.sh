#!/bin/bash

set -e
echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh # source the path.

if [ $# != 3 ]; then
    echo "usage: common/train_varikn_background.sh dir"
    
    exit 1;
fi

dir=$1
fn=$2
d=$3

e=$(python3 -c "print($d*2.0)")

varigram_kn -o $dir/${fn}.dev -n 80 -C -O "0 0 1" -3 -a -D $d -E $e $dir/${fn}.train $dir/arpa-$fn-$d 

