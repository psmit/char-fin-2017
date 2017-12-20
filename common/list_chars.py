#!/usr/bin/env python3

import sys
import collections

c = collections.Counter()
for line in sys.stdin:
  for ch in line.strip():
    c[ch] += 1

for k, v in c.most_common():
    print("{} {}".format(k,v))

