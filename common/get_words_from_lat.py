#!/usr/bin/env python2

from __future__ import print_function
import pywrapfst as fst
import sys

wordsfile = sys.argv[1]


st = fst.SymbolTable.read_text(wordsfile)

words_map = {}
for line in open(wordsfile):
    if len(line.strip()) == 0:
        continue
    word, i = line.strip().split()
    i = int(i)
    words_map[word] = i
   
if "<w>" in st:
    wtag = st.find("<w>")
else:
    wtag = None

unktag=st.find("<UNK>")

def read_fst(inp):
    compiler = fst.Compiler()
    while True:
        key = inp.readline().strip()
        if len(key) == 0:
            return
        while True:
            line = inp.readline()
            if len(line.strip()) == 0:
                break
            parts = line.split()
            if len(parts) > 4:
                parts = parts[:4]
            if len(parts) == 2:
                parts = parts[:1]
            print(" ".join(parts), file=compiler)
        yield key, compiler.compile()

if "<w>" in st:
    print("Word boundary mode", file=sys.stderr)

sequences = set()
for key, f in read_fst(sys.stdin):
    boundary_states = {0}
    between_states = set()

    f.topsort()
    for s in f.states():
        for i, a in enumerate(f.arcs(s)):
            sym = st.find(a.ilabel)
#            if sym == "<UNK>":
#                if s not in between_states:
#                    boundary_states.add(s)
#                if a.nextstate not in boundary_states:
#                    boundary_states.add(a.nextstate)
            if sym == "<w>":
                boundary_states.add(a.nextstate)
            if sym.startswith('+'):# and s not in boundary_states:
                between_states.add(s)
            if sym.endswith('+'):# and a.nextstate not in boundary_states:
                between_states.add(a.nextstate)

    assert len(boundary_states & between_states) == 0
    if "<w>" in st:
        for i, s in enumerate(f.states()):
            if i == 0:
                boundary_states.add(s)
            if s not in boundary_states:
                between_states.add(s) 
    else:
        for s in f.states():
            if s not in between_states:
                boundary_states.add(s)

    assert len(boundary_states & between_states) == 0
    
    print("{} Bound: {} Between: {} Total states: {} Sum: {} Num arcs: {}".format(key, len(boundary_states), len(between_states), f.num_states(), len(boundary_states | between_states), sum(f.num_arcs(s) for s in f.states())), file=sys.stderr)
    
    def dfs(state, cur_seq):
        global sequences
        global f
        if f.num_arcs(state) == 0:
            sequences.add(cur_seq)
        for a in f.arcs(state):
            if a.nextstate in boundary_states:
                sequences.add(cur_seq + (a.ilabel,))
            else:
                dfs(a.nextstate, cur_seq + (a.ilabel,))

    for s in boundary_states:
        dfs(s, tuple())    

for s in sequences:
    if len(s) == 0:
        continue
    if s[-1] == wtag:
        s = s[:-1]
    if len(s) == 0:
        continue
    if s[-1] == unktag:
        s = s[:-1]
    if len(s) == 0:
        continue
    print(" ".join(str(c) for c in s))# if c != wtag))

#if wtag is not None:
#    print(wtag)
#
#print(unktag)
