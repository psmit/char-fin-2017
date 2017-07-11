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
    assert base.startswith("morfseg")
    return 
def main(d):
    parse_name(d)

    word_count = collections.Counter()
    parent_dir = os.path.dirname(d)
    for f in os.listdir(parent_dir):
        if f.endswith(".xz"):
            for line in lzma.open(os.path.join(parent_dir, f), 'rt', encoding='utf-8'):
                for word in line.strip().split():
                    word_count[word] += 1
    print("Corpora read", file=sys.stderr)            
    allowed_chars = {line.strip() for line in open(os.path.join(parent_dir, 'allowed_chars'), encoding='utf-8') if len(line.strip()) == 1}
    
    model = morfessor.MorfessorIO().read_any_model(os.path.join(d, 'model.bin'))

    s = set()
    with open(os.path.join(d,'wordmap'), 'w', encoding='utf-8') as outf:
        for k in word_count.keys():
            parts = model.viterbi_segment(k)[0] 
            rparts = []
            for p in parts:
                if not all(c in allowed_chars for c in p):
                    p = '<UNK>'
                s.add(p)
                rparts.append(p)
            print("{}\t{}".format(k, " ".join(rparts)), file=outf)

    with open(os.path.join(d,'vocab2'), 'w', encoding='utf-8') as outf:
        for morph in s:
            print(morph, file=outf)

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    print("-".join(sys.argv))
    main(sys.argv[1])

