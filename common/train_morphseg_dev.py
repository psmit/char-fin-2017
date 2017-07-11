#!/usr/bin/env python3 

from __future__ import print_function

import morfessor
import sys
import collections
import logging
import lzma
import os
import math

def parse_name(d):
    base = os.path.basename(d)
    print(base ,file=sys.stderr)
    assert base.startswith("morf")
    return 
def main(d):
    parse_name(d)

    word_count = collections.Counter()
    print(d)
    seg_dir = os.path.dirname(d)
    print("seg_dir {}".format(seg_dir))
    for f in os.listdir(seg_dir):
        if f.endswith(".xz"):
            print(f)
            for line in lzma.open(os.path.join(seg_dir, f), 'rt', encoding='utf-8'):
                for word in line.strip().split():
                    word_count[word] += 1
    print("Corpora read", file=sys.stderr)            
    
    model = morfessor.MorfessorIO().read_any_model(os.path.join(d, 'model.bin'))

    s = set()
    with open(os.path.join(d,'wordmap_all'), 'w', encoding='utf-8') as outf:
        for k in word_count.keys():
            parts = model.viterbi_segment(k)[0] 
            rparts = []
            for p in parts:
                s.add(p)
                rparts.append(p)
            print("{}\t{}".format(k, " ".join(rparts)), file=outf)

    with open(os.path.join(d,'vocab_all'), 'w', encoding='utf-8') as outf:
        for morph in s:
            print(morph, file=outf)

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    print("-".join(sys.argv))
    main(sys.argv[1])

