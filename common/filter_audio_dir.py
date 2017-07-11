#!/usr/bin/env python3
import argparse
import locale
import os
import re
import sys

locale.setlocale(locale.LC_ALL, 'C')


def gen_utts(indir, filenames):
    filenames = set(filenames)
    files = {}

    def advance(f):
        files[f]['utt'], files[f]['val'] = None, ""
        try:
            parts = files[f]['file'].readline().strip().split(None, 1)
            files[f]['utt'] = parts[0]
            files[f]['val'] = parts[1]
        except:
            pass

    for filename in filenames:
        files[filename] = {}
        files[filename]['file'] = open(os.path.join(indir, filename), encoding='utf-8')
        advance(filename)

    all_run_out = False
    while not all_run_out:
        min_key = min((files[f]['utt'] for f in filenames if files[f]['utt'] is not None), key=locale.strxfrm)

        files_without_minkey = set(f for f in filenames if files[f]['utt'] != min_key)
        if len(files_without_minkey) > 0:
            print("Skipping utt {}, as it is not present in {}".format(min_key, ', '.join(sorted(files_without_minkey))), file=sys.stderr)
        else:
            yield min_key, {f: files[f]['val'] for f in filenames}

        for f in filenames - files_without_minkey:
            advance(f)

        all_run_out = all(files[f]['utt'] is None for f in filenames)


def main(indir, outdir, specs, ignores, utt_blacklist):
    filenames = set(os.listdir(indir)) - ignores
    filenames = {f for f in filenames if os.path.isfile(os.path.join(indir, f))}
    specs = open(specs, encoding='utf-8')
    key_r = re.compile(specs.readline().strip())
    val_rd = {p.split(None,1)[0]: re.compile(p.strip().split(None,1)[1]) for p in specs.readlines()}

    out_files = {filename: open(os.path.join(outdir, filename), 'w', encoding='utf-8') for filename in filenames}

    for utt, vals in gen_utts(indir, filenames):
        if utt in utt_blacklist:
            print("Skipping utt {}, because it is in the blacklist".format(utt), file=sys.stderr)
            continue
        if key_r.match(utt) is not None and all(r.match(vals[f]) is not None for f,r in val_rd.items()):
            for f in filenames:
                print("{} {}".format(utt, vals[f]), file=out_files[f])

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Filter directory with kaldi files (wav.scp wav.ark utt2type etc.')
    parser.add_argument('indir')
    parser.add_argument('outdir')
    parser.add_argument('specifications')
    parser.add_argument('blacklist', nargs='?', default=None)
   
    args = parser.parse_args()
    blacklist= set()

    if args.blacklist is not None and os.path.isfile(args.blacklist):
        blacklist = {l.strip() for l in open(args.blacklist, encoding='utf-8')}
    main(args.indir, args.outdir, args.specifications, {'wav.ark',},blacklist)
