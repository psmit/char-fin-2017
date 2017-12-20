#!/usr/bin/env python3
import argparse
import os


def main(dir):
    if not os.path.isfile(os.path.join(dir, 'text.ort2')):
        return
    with open(os.path.join(dir, 'text'), 'w', encoding='utf-8') as out_f:
        for line in open(os.path.join(dir, 'text.ort2'), encoding='utf-8'):
            try:
                key, sent = line.strip().split(None, 1)
            except:
                key = line.strip()
                sent = ""
            if len(sent) > 0 and sent[0] == "*":
                sent = sent[1:]
            sent = sent.replace("[sta]", " ").replace("  ", " ").replace("  ", " ")
            sent = sent.replace("_", "")
            sent = sent.replace("*", "")
            sent = " ".join(sent.split())
            print("{} {}".format(key, sent), file=out_f)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('dir')
    parser.add_argument('lexicon')

    args = parser.parse_args()

    main(args.dir)
