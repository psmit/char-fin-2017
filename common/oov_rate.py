#!/usr/bin/env python3

import sys

if len(sys.argv) > 3:
    vof = open(sys.argv[3], 'w', encoding='utf-8')
else:
    vof = None

vocab = set()
for line in open(sys.argv[1], encoding='utf-8'):
    vocab.add(line.strip())

print("Vocab size: {}".format(len(vocab)))

num_words = 0
oov = 0
for line in open(sys.argv[2], encoding='utf-8'):
    line = line.strip()
    if len(line) == 0:
        continue
    num_words += 1
    if line not in vocab:
        oov += 1
        if vof is not None:
            print(line, file=vof)

print("OOV's: {}".format(oov))
print("OOV rate: {}".format(oov/num_words)) 
