#!/bin/bash

export LC_ALL=C

# Begin configuration section.
inwordbackoff=true
# End configuration options.

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

if [ $# != 3 ]; then
   echo "usage: common/make_recog_lang.sh arpa source_lang target_lang"
   echo "e.g.:  common/make_recog_lang data/word_lm/srilm_20k_3gram/arpa.xz data/langs/word_20k/ data/recog_langs/word_s_20k_3gram"
   echo "main options (for others, see top of script file)"
   echo "     --inwordbackoff (true|false)   # Create a separate inword-backoff node in G.fst"
   exit 1;
fi

arpa=$1
sourcelang=$2
targetlang=$3

if [ -e ${targetlang} ]; then
rm -Rf ${targetlang}
fi

mkdir -p $(dirname ${targetlang})
cp -R ${sourcelang} ${targetlang}

if $inwordbackoff; then
    cat ${arpa} | arpa2fst --disambig-symbol="#0" --read-symbol-table=${targetlang}/words.txt - - | fstprint | common/inword_backoff_node.py --symbols=${targetlang}/words.txt | fstcompile | fstrmepsilon | fstarcsort > ${targetlang}/G.fst
else
    cat ${arpa} | arpa2fst --disambig-symbol="#0" --read-symbol-table=${targetlang}/words.txt - ${targetlang}/G.fst
fi
