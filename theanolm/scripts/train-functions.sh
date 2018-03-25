#!/bin/bash -e
#
# Functions for estimating language models.

source "${PROJECT_SCRIPT_DIR}/defs.sh"
source "${PROJECT_SCRIPT_DIR}/vocab-functions.sh"


interpolate_kn () {
	local model_file="${1}"
	shift

	local ngram_order=$(zcat -f -- "${@}" |
	  sed -r -n 's/^ngram ([0-9]+)=[0-9]+$/\1/p' |
	  sort -n |
	  tail -1)

	local weights_file="${EXPT_WORK_DIR}/weights"
	local ngram_cmd="$(which ngram)"
	[ -x "${ngram_cmd}" ] || { echo "ngram not found. Have you loaded srilm module?" >&2; exit 1; }

	declare -a args=(--ngram-cmd "${ngram_cmd}")
	args+=(--order "${ngram_order}")
	[ -n "${CLASSES}" ] && args+=(--classes "${CLASSES}")
	[ "${OPEN_VOCABULARY_NGRAM}" ] && args+=(--unk)
	[ -n "${OOV_TOKEN}" ] && args+=(--map-unk "${OOV_TOKEN}")
	args+=(--opt-perp "${DEVEL_FILE}")
	args+=(--output "${model_file}")
	args+=(--write-weights "${weights_file}")
	args+=("${@}")

	(set -x; "${HOME}/git/senarvi-speech/lm-tools/interpolate-lm.py" "${args[@]}")
}

estimate_srilm () {
	# Output language model file.
	local model_file="${1}"
	shift

	# Vocabulary file contains one word per line. Any text following the word
	# such as counts will be ignored.
	local vocab_file="${1}"
	shift

	local ngram_order="${NGRAM_ORDER:-4}"
	declare -a args=(-order "${ngram_order}")
	if [ "${OPEN_VOCABULARY_NGRAM}" ]
	then
		args+=(-unk)
	else
		args+=(-limit-vocab)
	fi
	args+=(-interpolate1 -interpolate2 -interpolate3 -interpolate4 -interpolate5 -interpolate6)
	args+=(-gt4min 2 -gt5min 2 -gt6min 2)
	args+=(-text -)
	args+=(-lm "${model_file}")
	args+=("${@}")

	echo ngram-count "${args[@]}" -vocab "<(cut -f1 ${vocab_file})"
	ngram-count "${args[@]}" -vocab <(cut -f1 "${vocab_file}")
}

estimate_varikn () {
	# Output language model file.
	local model_file="${1}"
	# Training data file.
	local train_file="${2}"

	declare -a args=(--opti="${DEVEL_FILE}")
	[ -n "${VARIKN_DSCALE}" ] && args+=(--dscale "${VARIKN_DSCALE}")
	[ -n "${VARIKN_DSCALE2}" ] && args+=(--dscale2 "${VARIKN_DSCALE2}")
	[ -n "${NGRAM_ORDER}" ] && args+=(--norder "${NGRAM_ORDER}")
	args+=(--clear_history --arpa --3nzer --discard_unks --longint)

	(set -x; varigram_kn "${args[@]}" "${train_file}" - |
	  sed 's/-60/-99/g' |
	  sed 's/<UNK>/<unk>/g' \
	  >"${model_file}")
}

concatenate_corpora () {
	if [ -n "${1}" ]
	then
		declare -a train_files=("${!1}")
	else
		declare -a train_files=("${TRAIN_FILES[@]}")
	fi

	[ -n "${SENTENCE_LIMIT}" ] || SENTENCE_LIMIT="-0"

	if [ -n "${CLASSES}" ]
	then
		# head will make gzip return a non-zero exit code.
		gzip --stdout --decompress --force "${train_files[@]}" |
		  grep -v '######' |
		  head --lines="${SENTENCE_LIMIT}" |
		  replace-words-with-classes classes="$CLASSES" || true
	else
		# head will make gzip return a non-zero exit code.
		gzip --stdout --decompress --force "${train_files[@]}" |
		  grep -v '######' |
		  head --lines="${SENTENCE_LIMIT}" || true
	fi

	return 0
}

# Normalizes numbers in a file so that the maximum is one.
normalize () {
	awk 'BEGIN {
	    next_index = 0;
	    max_weight = 0;
	  }
	  {
	    weights[next_index++] = $0
	    if ($0 > max_weight) {
	      max_weight = $0;
	    }
	  }
	  END {
	    for (i = 0; i < length(weights); i++) {
	      print(weights[i] / max_weight);
	    }
	  }' "${1}"
}

# Train a Kneser-Ney model from given text with SRILM. If Kneser-Ney
# smoothing fails for some order, use Witten-Bell.
train_kn_single () {
	if [ -n "${1}" ]
	then
		declare -a train_files=("${!1}")
	else
		declare -a train_files=("${TRAIN_FILES[@]}")
	fi
	local model_file="${2}"
	local vocab_file="${3}"

	echo "${model_file} :: ${train_files[@]}"

	[[ ${-} = *e* ]]; local errexit="${?}"
	set +e

	declare -a discounting=(-kndiscount1 -kndiscount2 -kndiscount3 -kndiscount4 -kndiscount5 -kndiscount6)
	concatenate_corpora train_files[@] |
	  estimate_srilm "${model_file}" "${vocab_file}" "${discounting[@]}"
	if [[ ${?} -ne 0 ]]
	then
		discounting=(-kndiscount1 -kndiscount2 -kndiscount3 -kndiscount4 -kndiscount5 -wbdiscount6)
		echo "Failed. Trying ${discounting[@]}."
		concatenate_corpora train_files[@] |
		  estimate_srilm "${model_file}" "${vocab_file}" "${discounting[@]}"
	fi
	if [[ ${?} -ne 0 ]]
	then
		discounting=(-kndiscount1 -kndiscount2 -kndiscount3 -kndiscount4 -wbdiscount5 -wbdiscount6)
		echo "Failed. Trying ${discounting[@]}."
		concatenate_corpora train_files[@] |
		  estimate_srilm "${model_file}" "${vocab_file}" "${discounting[@]}"
	fi
	if [[ ${?} -ne 0 ]]
	then
		discounting=(-kndiscount1 -kndiscount2 -kndiscount3 -wbdiscount4 -wbdiscount5 -wbdiscount6)
		echo "Failed. Trying ${discounting[@]}."
		concatenate_corpora train_files[@] |
		  estimate_srilm "${model_file}" "${vocab_file}" "${discounting[@]}"
	fi
	if [[ ${?} -ne 0 ]]
	then
		discounting=(-kndiscount1 -kndiscount2 -wbdiscount3 -wbdiscount4 -wbdiscount5 -wbdiscount6)
		echo "Failed. Trying ${discounting[@]}."
		concatenate_corpora train_files[@] |
		  estimate_srilm "${model_file}" "${vocab_file}" "${discounting[@]}"
	fi
	if [[ ${?} -ne 0 ]]
	then
		discounting=(-kndiscount1 -wbdiscount2 -wbdiscount3 -wbdiscount4 -wbdiscount5 -wbdiscount6)
		echo "Failed. Trying ${discounting[@]}."
		concatenate_corpora train_files[@] |
		  estimate_srilm "${model_file}" "${vocab_file}" "${discounting[@]}"
	fi
	if [[ ${?} -ne 0 ]]
	then
		discounting=(-wbdiscount1 -wbdiscount2 -wbdiscount3 -wbdiscount4 -wbdiscount5 -wbdiscount6)
		echo "Failed. Trying ${discounting[@]}."
		concatenate_corpora train_files[@] |
		  estimate_srilm "${model_file}" "${vocab_file}" "${discounting[@]}"
	fi

	(( ${errexit} == 0 )) && set -e
}

train_kn () {
	if [ -n "${1}" ]
	then
		declare -a train_files=("${!1}")
	else
		declare -a train_files=("${TRAIN_FILES[@]}")
	fi

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	mkdir -p "${EXPT_WORK_DIR}"

	local model_file="${EXPT_WORK_DIR}/kn.arpa.gz"
	local vocab_file  # Word or class vocabulary, depending on model type.
	if [ -n "${CLASSES}" ]
	then
		local vocab_file="${EXPT_WORK_DIR}/class.vocab"
		create_class_vocabulary
	elif [ -n "${VOCAB_SIZE}" ]
	then
		vocab_file="${EXPT_WORK_DIR}/word-${VOCAB_SIZE}.vocab"
		# head will make concatenate_corpora return a non-zero exit code.
		concatenate_corpora train_files[@] |
		  ngram-count -order 1 -no-sos -no-eos -text - -write - |
		  sort -g -k 2,2 -r |
		  head --lines="${VOCAB_SIZE}" \
		  >"${vocab_file}" || true
	else
		vocab_file="${EXPT_WORK_DIR}/word.vocab"
		concatenate_corpora train_files[@] |
		  ngram-count -order 1 -text - -no-sos -no-eos -write-vocab - |
		  egrep -v '(-pau-|<s>|</s>|<unk>)' \
		  >"${vocab_file}"
	fi

	train_kn_single train_files[@] "${model_file}" "${vocab_file}"

	echo "train_kn finished."
}

# Train Kneser-Ney models and interpolate with SRILM.
train_kn_ip () {
	if [ -n "${1}" ]
	then
		declare -a train_files=("${!1}")
	else
		declare -a train_files=("${TRAIN_FILES[@]}")
	fi

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	mkdir -p "${EXPT_WORK_DIR}"

	local model_file="${EXPT_WORK_DIR}/kn.arpa.gz"
	local vocab_file  # Word or class vocabulary, depending on model type.
	if [ -n "${CLASSES}" ]
	then
		local vocab_file="${EXPT_WORK_DIR}/class.vocab"
		create_class_vocabulary
	elif [ -n "${VOCAB_SIZE}" ]
	then
		vocab_file="${EXPT_WORK_DIR}/word-${VOCAB_SIZE}.vocab"
		select_vocabulary "${vocab_file}" "${VOCAB_SIZE}" "${DEVEL_FILE}" "${train_files[@]}"
	else
		vocab_file="${EXPT_WORK_DIR}/word.vocab"
		concatenate_corpora train_files[@] |
		  ngram-count -order 1 -text - -no-sos -no-eos -write-vocab - |
		  egrep -v '(-pau-|<s>|</s>|<unk>)' \
		  >"${vocab_file}"
	fi

	declare -a sub_model_files
	for train_file in "${train_files[@]}"
	do
		local basename=$(basename "${train_file}" .txt)
		local sub_model_file="${EXPT_WORK_DIR}/${basename}.arpa.gz"
		train_kn_single train_file "${sub_model_file}" "${vocab_file}"
		sub_model_files+=("${sub_model_file}")
	done

	interpolate_kn "${model_file}" "${sub_model_files[@]}"

	rm -f "${sub_model_files[@]}"
	echo "train_kn_ip finished."
}

# Train a Kneser-Ney models with variKN.
train_varikn () {
	if [ -n "${1}" ]
	then
		declare -a train_files=("${!1}")
	else
		declare -a train_files=("${PROJECT_DIR}/data/segmented/dsp.txt" \
		                        "${PROJECT_DIR}"/data/segmented/web{1..6}.txt)
	fi

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	mkdir -p "${EXPT_WORK_DIR}"

	local train_all_file="${EXPT_WORK_DIR}/train.txt"
	cat "${train_files[@]}" >"${train_all_file}"

	local model_file="${EXPT_WORK_DIR}/kn.arpa"
	estimate_varikn "${model_file}" "${train_all_file}"
	gzip -f "${model_file}"

	rm -f "${train_all_file}"
	echo "train_varikn finished."
}

# Train Kneser-Ney models with variKN and interpolate with SRILM.
train_varikn_ip () {
	if [ -n "${1}" ]
	then
		declare -a train_files=("${!1}")
	else
		declare -a train_files=("${PROJECT_DIR}/data/segmented/dsp.txt" \
		                        "${PROJECT_DIR}"/data/segmented/web{1..6}.txt)
	fi

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	mkdir -p "${EXPT_WORK_DIR}"

	declare -a sub_model_files
	for train_file in "${train_files[@]}"
	do
		local basename=$(basename "${train_file}" .txt)
		local sub_model_file="${EXPT_WORK_DIR}/${basename}.arpa"
		estimate_varikn "${sub_model_file}" "${train_file}"
		sub_model_files+=("${sub_model_file}")
	done

	local model_file="${EXPT_WORK_DIR}/kn.arpa.gz"
	interpolate_kn "${model_file}" "${sub_model_files[@]}"

	rm -f "${sub_model_files[@]}"
	echo "train_varikn_ip finished."
}

# Train a neural network model with TheanoLM.
train_theanolm () {
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	local sequence_length="${SEQUENCE_LENGTH:-25}"
	local batch_size="${BATCH_SIZE:-32}"
	local optimization_method="${OPTIMIZATION_METHOD:-adagrad}"
	local stopping_criterion="${STOPPING_CRITERION:-annealing-count}"
	local cost="${COST:-cross-entropy}"
	local learning_rate="${LEARNING_RATE:-0.1}"
	local gradient_decay_rate="${GRADIENT_DECAY_RATE:-0.9}"
	local epsilon="${EPSILON:-1e-6}"
	local num_noise_samples="${NUM_NOISE_SAMPLES:-1000}"
	local noise_dampening="${NOISE_DAMPENING:-0.75}"
	local noise_sharing="${NOISE_SHARING:-batch}"
	local validation_freq="${VALIDATION_FREQ:-8}"
	local patience="${PATIENCE:-4}"
	local max_epochs="${MAX_EPOCHS:-15}"

	source "${PROJECT_SCRIPT_DIR}/configure-theano.sh"

	declare -a extra_args
	[ -n "${MAX_GRADIENT_NORM}" ] && extra_args+=(--gradient-normalization "${MAX_GRADIENT_NORM}")
	if [ -n "${IGNORE_UNK}" ]
        then
		#extra_args+=(--unk-penalty 0)
		extra_args+=(--exclude-unk)
	elif [ -n "${UNK_PENALTY}" ]
	then
		extra_args+=(--unk-penalty="${UNK_PENALTY}")
	fi
	if [ -n "${DEBUG}" ]
	then
		extra_args+=(--debug)
		THEANO_FLAGS="${THEANO_FLAGS},optimizer=None"
	fi
	if [ -n "${PROFILE}" ]
	then
		extra_args+=(--print-graph --profile)
		THEANO_FLAGS="${THEANO_FLAGS},profiling.ignore_first_call=True"
		export CUDA_LAUNCH_BLOCKING=1
	fi
	[ -n "${ARCHITECTURE}" ] && extra_args+=(--architecture "${PROJECT_DIR}/configs/${ARCHITECTURE}.arch")
	[ -n "${NUM_GPUS}" ] && extra_args+=(--default-device "dev0")

	mkdir -p "${EXPT_WORK_DIR}"

	declare -a weights
	if [ -n "${WEIGHTS}" ]
	then
		readarray -t weights < <(normalize "${WEIGHTS}")
#		extra_args+=(--weights "${weights[@]}")
		extra_args+=(--sampling "${weights[@]}")
	elif [ -s "${EXPT_WORK_DIR}/weights" ]
	then
		readarray -t weights < <(normalize "${EXPT_WORK_DIR}/weights")
		extra_args+=(--weights "${weights[@]}")
	fi

	export THEANO_FLAGS
#	echo "${PYTHONPATH}" | tr ':' '\n' | grep '\/Theano\/' || { echo "Theano not found in PYTHONPATH." >&2; exit 1; }
	echo "${THEANO_FLAGS}"
	theanolm version
	echo "=="

	# Taining vocabulary or classes.
	if [ -n "${CLASSES}" ]
	then
		extra_args+=(--vocabulary "${CLASSES}")
		if [ "${CLASSES##*.}" == "sricls" ]
		then
			extra_args+=(--vocabulary-format "srilm-classes")
		else
			extra_args+=(--vocabulary-format "classes")
		fi
	else
		if [ -n "${VOCAB_SIZE}" ]
		then
			local vocab_file="${EXPT_WORK_DIR}/nnlm.vocab"
			if [ -n "${VOCAB_ORDER}" ]
			then
				select_ordered_vocabulary \
				  "${vocab_file}" "${VOCAB_SIZE}" \
				  "${VOCAB_ORDER}" "${DEVEL_FILE}" \
				  "${TRAIN_FILES[@]}"
			else
				select_vocabulary \
				  "${vocab_file}" "${VOCAB_SIZE}" \
				  "${DEVEL_FILE}" "${TRAIN_FILES[@]}"
			fi
			extra_args+=(--vocabulary "${vocab_file}")
			extra_args+=(--vocabulary-format "words")
		fi
	fi

	set -x
	${RUN_GPU} theanolm train \
	  "${EXPT_WORK_DIR}/nnlm.h5" \
	  --training-set "${TRAIN_FILES[@]}" \
	  --validation-file "${DEVEL_FILE}" \
	  --sequence-length "${sequence_length}" \
	  --batch-size "${batch_size}" \
	  --optimization-method "${optimization_method}" \
	  --stopping-criterion "${stopping_criterion}" \
	  --cost "${cost}" \
	  --learning-rate "${learning_rate}" \
	  --gradient-decay-rate "${gradient_decay_rate}" \
	  --numerical-stability-term "${epsilon}" \
	  --num-noise-samples "${num_noise_samples}" \
	  --noise-dampening "${noise_dampening}" \
	  --noise-sharing "${noise_sharing}" \
	  --validation-frequency "${validation_freq}" \
	  --patience "${patience}" \
	  --max-epochs "${max_epochs}" \
	  --min-epochs 1 \
	  --random-seed 1 \
	  --log-level debug \
	  --log-interval "${LOG_INTERVAL:-1000}" \
          "${extra_args[@]}"
	set +x
	echo "train_theanolm finished."
}
