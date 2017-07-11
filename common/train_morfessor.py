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
    assert base.startswith("morfessor")
    parts = base.split('_')
    freq = int(parts[1][1:])
    alpha = float(parts[2][1:])
    damp = parts[3]
    return freq, alpha, damp
def main(d):
    freq, alpha, damp = parse_name(d)

    word_count = collections.Counter()
    parent_dir = os.path.dirname(d)
    for f in os.listdir(parent_dir):
        if f.endswith(".xz") and not f.startswith("dev") and not f.startswith("eval") and not f.startswith("test"):
            print("Read {}".format(f),file=sys.stderr)
            for line in lzma.open(os.path.join(parent_dir, f), 'rt', encoding='utf-8'):
                for word in line.strip().split():
                    word_count[word] += 1
    print("Corpora read", file=sys.stderr)            
    allowed_chars = {line.strip() for line in open(os.path.join(parent_dir, 'allowed_chars'), encoding='utf-8') if len(line.strip()) == 1}
    
    model = morfessor.BaselineModel(corpusweight=alpha)
    assert damp in {'types', 'tokens', 'logtokens'}
    damp_func = None
    if damp == 'types':
        damp_func = lambda x: 1
    elif damp == 'logtokens':
        damp_func = lambda x: int(round(math.log(x + 1, 2)))

    data = [(v,k) for k,v in word_count.items() if all(c in allowed_chars for c in k)] 
    model.load_data(data, freq, damp_func)
    model.train_batch()
    
    io = morfessor.MorfessorIO()
    io.write_binary_model_file(os.path.join(d,'model.bin'), model)

    io.write_segmentation_file(os.path.join(d,'model.txt'), model.get_segmentations())

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

    with open(os.path.join(d,'vocab'), 'w', encoding='utf-8') as outf:
        for morph in s:
            print(morph, file=outf)

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    main(sys.argv[1])
