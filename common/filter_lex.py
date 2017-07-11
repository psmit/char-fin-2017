#!/usr/bin/env python3
import argparse
from signal import signal, SIGPIPE, SIG_DFL 
#Ignore SIG_PIPE and don't throw exceptions on it... (http://docs.python.org/library/signal.html)
signal(SIGPIPE,SIG_DFL) 

def main(in_lex, vocab, out_lex, oov, nfirst=None):
    d = {}
    for line in in_lex:
        try:
            key, trans = line.strip().split(None, 1)
            if key not in d:
                d[key] = set()
            d[key].add(trans)
        except:
            pass

    printed = 0
    for line in vocab:
        if nfirst is not None and printed >= nfirst:
            break
        word = line.strip().split()[0]

        if word in d:
            printed += 1
            for trans in d[word]:
                print("{}\t{}".format(word, trans), file=out_lex)
        else:
            print(word, file=oov)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('inlex', type=argparse.FileType('r', encoding='utf-8'))
    parser.add_argument('invocab', type=argparse.FileType('r', encoding='utf-8'))
    parser.add_argument('outlex', type=argparse.FileType('w', encoding='utf-8'))
    parser.add_argument('oovlist', type=argparse.FileType('w', encoding='utf-8'))
    parser.add_argument("--nfirst", type=int, default=None)
    args = parser.parse_args()

    main(args.inlex, args.invocab, args.outlex, args.oovlist, args.nfirst)
