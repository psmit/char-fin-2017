#!/usr/bin/env python3
import argparse
import lzma
import random


def main(inp_f, p, of1, of2):
    for line in open(inp_f, 'r', encoding='utf-8'):
        line = line.strip()
        if not line.startswith("<s>"):
            line = "<s> " + line
        if not line.endswith("</s>"):
            line = line + " </s>"

        if random.random() < p :
            print(line, file=of1)
        else:
            print(line, file=of2)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='')
    parser.add_argument('infile')
    parser.add_argument('percentage', type=float)
    parser.add_argument('out1', type=argparse.FileType('w', encoding='utf-8'))
    parser.add_argument('out2', type=argparse.FileType('w', encoding='utf-8'))

    args = parser.parse_args()

    main(args.infile, args.percentage, args.out1, args.out2)

