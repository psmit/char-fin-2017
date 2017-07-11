#!/bin/bash

utils/build_const_arpa_lm.sh <(gzip -c < $1) $2 $3
