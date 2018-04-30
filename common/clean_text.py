#!/usr/bin/env python3

import fileinput
import unicodedata

for line in fileinput.input():
    nwords = []
    for word in line.split():
        if not all(unicodedata.category(c)[0] == 'P' for c in word):
            nwords.append(word.strip(".,!:"))
    if len(nwords) > 0: 
        print(" ".join(nwords))
