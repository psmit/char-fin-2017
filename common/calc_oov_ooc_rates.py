#!/usr/bin/env python3

import sys

hyp=sys.argv[1]
ref=sys.argv[2]
corpusvocab={line.strip() for line in open(sys.argv[3], encoding='utf-8')}

hyps = {}
for line in open(hyp, encoding='utf-8'):
    parts = line.strip().split()
    hyps[parts[0]] = parts[1:]

total = 0
oovs = 0
found = 0

for line in open(ref, encoding='utf-8'):
    r_parts = line.split()
    h = hyps[r_parts[0]]

    for word in r_parts[1:]:
        total += 1
        if word not in corpusvocab:
            oovs += 1
            if word in h:
                 found += 1
print("{} {} {} {} {}".format(total, oovs, found, oovs/total, found/oovs))

