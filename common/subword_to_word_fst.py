#!/usr/bin/env python3

import sys

wb=int(sys.argv[1])

word_boundary_mode = False
if wb > 0:
    word_boundary_mode = True


#start-state (loop-state) = 0
#end-state = 1
#before-end-state (in case of <w>) = 2

from_state=0
to_state=0
next_state=1
if word_boundary_mode:
    from_state=1
    next_state=2
    print("{}\t{}\t{}\t{}".format(to_state, from_state, wb, 0))

def print_word(w,sws):
    global next_state
    global from_state
    global to_state
   
    cur_state = from_state  
    while len(sws) > 1:
        print("{}\t{}\t{}\t{}".format(cur_state, next_state, sws[0], w))
        cur_state = next_state
        next_state += 1
        w = 0
        sws = sws[1:]
    assert len(sws) == 1
    print("{}\t{}\t{}\t{}".format(cur_state, to_state, sws[0], w))
    

for line in sys.stdin:
    parts = line.strip().split()
    assert len(parts) > 1
    word = parts[0]
    subwords = parts[1:]

    print_word(word,subwords)


print("{}".format(from_state))
