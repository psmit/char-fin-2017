#!/usr/bin/env python3

import fileinput

seconds = []
mems = []
for line in fileinput.input():
    mem, time = line.split()
    h,m,s = time.split(':')
    seconds.append( int(s) + 60* int(m) + 3600 * int(h))
    assert mem[-1] == 'M'
    mems.append(int(mem[:-1]))

print("{} jobs".format(len(mems)))
print("Seconds total: {}, avg: {}".format(sum(seconds), sum(seconds)/len(seconds)))
print("Mem min {}, max {}, avg: {}".format(min(mems), max(mems), sum(mems)/len(mems)))
