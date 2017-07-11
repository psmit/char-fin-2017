#!/bin/bash


set -euo pipefail



[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

if [ $# -ne 1 ]; then
   echo "usage: common/select_best.sh interp_dir"
   echo "main options (for others, see top of script file)"

   exit 1;
fi

dir=$1


bestdir=$(dirname $(find $dir -name "best_*wer" | xargs cat | sort -g -k2 | awk '{print $NF}' | head -n1))
if [ -e $dir/best ]; then
rm $dir/best
fi
ln -rs $bestdir $dir/best

