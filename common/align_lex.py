#!/usr/bin/env python3

import fileinput
import itertools
import sys

assert len(sys.argv) > 1
t = sys.argv[1]
assert t in ("pre", "suf", "aff", "wma")


for line in sys.stdin:
    parts = line.split()
    assert len(parts) >= 3

    if parts[0] == '<w>':
        parts[2] = "SIL"
        print(" ".join(parts))
        parts[2] = ""
        print(" ".join(parts))
        continue

    if parts[2].startswith("SIL") or parts[2].startswith("SPN"):
        print(" ".join(parts))
        continue
    assert all("_" in p for p in parts[2:])
    
    is_begin = None
    is_end = None

    if parts[0].startswith('+'):
        is_begin = False
    elif t in ("aff", "pre"):
        is_begin = True

    if parts[0].endswith('+'):
        is_end = False
    elif t in ("aff", "suf"):
        is_end = True

    if len(parts) == 3:
        opts = {'B', 'I', 'E', 'S'}
        if is_begin is True:
            opts.discard('E')
            opts.discard('I')
        if is_end is True:
            opts.discard('I')
            opts.discard('B')
        if is_begin is False:
            opts.discard('B')
            opts.discard('S')
        if is_end is False:
            opts.discard('E')
            opts.discard('S')
        assert len(opts) > 0
        for e in opts:
            parts[2] = parts[2][:-1] + e
            print(" ".join(parts))
        continue

    # If we are here we have more then 1 phone
    bopts = {'B', 'I'}
    if is_begin is True:
        bopts.discard('I')
    if is_begin is False:
        bopts.discard('B')

    eopts = {'E', 'I'}
    if is_end is True:
        eopts.discard('I')
    if is_end is False:
        eopts.discard('E')

    for bp, ep in itertools.product(bopts, eopts):
        parts[2] = parts[2][:-1] + bp 
        parts[-1] = parts[-1][:-1] + ep 
        print(" ".join(parts))
