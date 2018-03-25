#!/bin/bash -e
#
# Functions for creating vocabularies.

source "${PROJECT_SCRIPT_DIR}/defs.sh"


select_vocabulary () {
	local vocab_file="${1}"
	shift
	local vocab_size="${1}"
	shift
	local devel_file="${1}"
	shift

	command -v select-vocab >/dev/null 2>&1 || { echo >&2 "select-vocab not found. Have you loaded srilm module?"; exit 1; }

	# Sort in $WORK_DIR. There may not be enough space in $TMPDIR.
	mkdir -p "${WORK_DIR}/tmp"

	if [ ! -s "${vocab_file}" ]
	then
		# select-vocab always returns a non-zero exit code.
		[[ ${-} = *e* ]]; local errexit="${?}"
		set +e
		select-vocab -heldout "${devel_file}" "${@}" \
		| grep -v '^-' \
		| sort -s -g -k 2,2 -r -T "${WORK_DIR}/tmp" \
		| head -"${vocab_size}" \
		| cut -f1 \
		>"${vocab_file}"
		(( ${errexit} == 0 )) && set -e
	fi
}

select_vocabulary_with_counts () {
	local vocab_file="${1}"
	shift
	local vocab_size="${1}"
	shift
	local devel_file="${1}"
	shift

	command -v select-vocab >/dev/null 2>&1 || { echo >&2 "select-vocab not found. Have you loaded srilm module?"; exit 1; }

	# Sort in $WORK_DIR. There may not be enough space in $TMPDIR.
	mkdir -p "${WORK_DIR}/tmp"

	if [ ! -s "${vocab_file}" ]
	then
		# select-vocab always returns a non-zero exit code.
		[[ ${-} = *e* ]]; local errexit="${?}"
		set +e
		select-vocab -heldout "${devel_file}" "${@}" \
		| grep -v '^-' \
		| sort -s -g -k 2,2 -r -T "${WORK_DIR}/tmp" \
		| head -"${vocab_size}" \
		| awk '{ printf "%s\t%.0f\n", $1, $2 * 1000 }' \
		>"${vocab_file}"
		(( ${errexit} == 0 )) && set -e
	fi
}

# Selects a vocabulary with given number of words. The words will be sorted by
# class according to the given classes file.
select_ordered_vocabulary () {
	local vocab_file="${1}"
	shift
	local vocab_size="${1}"
	shift
	local classes_file="${1}"
	shift
	local devel_file="${1}"
	shift

	local vocab_order="${EXPT_WORK_DIR}/classes-order.vocab"
	grep -v '^<' "${classes_file}" |
	  sort -k2n |
	  cut -f1 \
	  >"${vocab_order}"

	local unordered_vocab_file="${EXPT_WORK_DIR}/unordered.vocab"
	select_vocabulary "${unordered_vocab_file}" "${vocab_size}" "${devel_file}" "${@}"

	awk '{
	    if (NR == FNR) { vocab[$1] = 1 }
	    else { if ($1 in vocab) { print $1 } }
	  }' \
	  "${unordered_vocab_file}" \
	  "${vocab_order}" \
	  >"${vocab_file}"
}

# Creates class.vocab with all the class names, and if
# $ALLOW_WORDS_IN_CLASS_VOCABULARY is set, includes words that do not exist in
# any class.
create_class_vocabulary () {
	[ -s "${CLASSES}" ] || { echo "${CLASSES} not found or empty." >&2; exit 1; }

	local vocab_file="${EXPT_WORK_DIR}/class.vocab"
	echo "${vocab_file} :: ${CLASSES}"
	cut -f1 -d' ' "${CLASSES}" | sort -u >"${vocab_file}"

	local word_vocab_file
	if [ -n "${ALLOW_WORDS_IN_CLASS_VOCABULARY}" ]
	then
		word_vocab_file="${EXPT_WORK_DIR}/word"
		[ -n "${VOCAB_SIZE}" ] && word_vocab_file="${word_vocab_file}-${VOCAB_SIZE}"
		if [ -s "${word_vocab_file}.vocab" ]
		then
			word_vocab_file="${word_vocab_file}.vocab"
		elif [ -s "${word_vocab_file}.1cnt" ]
		then
			word_vocab_file="${word_vocab_file}.1cnt"
		elif [ -n "${VOCAB_SIZE}" ]
		then
			word_vocab_file="${word_vocab_file}.vocab"
			# head will make concatenate_corpora return a non-zero exit code.
			concatenate_corpora train_files[@] |
			  ngram-count -order 1 -no-sos -no-eos -text - -write - |
			  sort -g -k 2,2 -r |
			  head --lines="${VOCAB_SIZE}" \
			  >"${word_vocab_file}" || true
		else
			word_vocab_file="${word_vocab_file}.vocab"
			concatenate_corpora train_files[@] |
			  ngram-count -order 1 -text - -no-sos -no-eos -write-vocab - |
			  egrep -v '(-pau-|<s>|</s>|<unk>)' \
			  >"${word_vocab_file}"
		fi
		echo "${vocab_file} :: ${word_vocab_file}"
		comm -2 -3 <(cut -f1 "${word_vocab_file}" | sort -u) \
		           <(cut -f3 -d' ' "${CLASSES}" | sort -u) \
		>>"${vocab_file}"
	fi
}

train_morfessor () {
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	local dampening="${MORFESSOR_DAMPENING:-ones}"
	local corpus_weight="${MORFESSOR_CORPUS_WEIGHT:-1.0}"

	mkdir -p "${EXPT_WORK_DIR}"

	declare -a extra_args
	for file in "${TRAIN_FILES[@]}"
	do
		extra_args+=(--traindata "${file}")
	done

	local model_file="${EXPT_WORK_DIR}/morfessor.model"
	echo "${model_file}"
	(set -x; morfessor \
	  "${extra_args[@]}" \
	  --encoding 'UTF-8' \
	  --dampening "${dampening}" \
	  --corpusweight "${corpus_weight}" \
	  --save "${model_file}")

	rm -f "${model_file}.gz"
	gzip "${model_file}"

	echo "train_morfessor finished."
}

segment_vocabulary () {
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	local model_file="${EXPT_WORK_DIR}/morfessor.model.gz"

	local vocab_file="${EXPT_WORK_DIR}/word-all.vocab"
	if [ ! -s "${vocab_file}" ]
	then
		echo "${vocab_file}"
		cat "${TRAIN_FILES[@]}" "${DEVEL_FILE}" "${EVAL_FILE}" |
		  ngram-count -order 1 -text - -no-sos -no-eos -write-vocab - |
		  egrep -v '(-pau-|<s>|</s>|<unk>)' \
		  >"${vocab_file}"
	fi

	local segment_file="${EXPT_WORK_DIR}/morfessor.segment"
        echo "${segment_file}"
        morfessor-segment \
	  --load <(zcat "${model_file}") \
	  --encoding 'UTF-8' \
	  --output "${segment_file}" \
	  --verbose 3 \
	  <(cut -f 1 "${vocab_file}")
	echo "morfessor-segment returned"

	rm -f "${segment_file}.gz"
	gzip "${segment_file}"

	echo "segment_vocabulary finished."
}

segment_text () {
	local in_file="${1}"
	local out_file="${2}"

	local segment_file="${EXPT_WORK_DIR}/morfessor.segment.gz"

	echo "${out_file} :: ${in_file}"
	grep -v '^\s*$' "${in_file}" |
	  segment-text.py <(zcat "${segment_file}") |
	  gzip \
	  >"${out_file}"
}

segment_data () {
	local out_dir="${EXPT_WORK_DIR}/segmented-data"
	mkdir -p "${out_dir}"

	for in_file in "${TRAIN_FILES[@]}"
	do
		local basename=$(basename "${in_file}" .txt)
		local out_file="${out_dir}/${basename}.txt.gz"
		segment_text "${in_file}" "${out_file}"
	done

	segment_text "${DEVEL_FILE}" "${out_dir}/devel.txt.gz"
	segment_text "${EVAL_FILE}" "${out_dir}/eval.txt.gz"

	echo "segment_data finished."
}
