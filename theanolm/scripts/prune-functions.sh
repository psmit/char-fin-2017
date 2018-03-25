#!/bin/bash
#
# Prune language models and convert to binary format.

if ! which vocab2lex-fi.pl >/dev/null
then
	echo "Please load speech-scripts module first."
	exit 1
fi

binarize () {
	local model_file="${1}"
	local lookahead_file="${2}"
	local model_bin_file="${3}"
	local lookahead_bin_file="${4}"

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	echo "${model_bin_file} :: ${model_file}"
	fsalm-convert --arpa="${model_file}" --out-bin="${model_bin_file}"
	echo "${lookahead_bin_file} :: ${lookahead_file}"
	arpa2bin <"${lookahead_file}" >"${lookahead_bin_file}"
}

# Creates a dictionary from vocabulary (possibly with counts).
create_dictionary () {
	local vocab_file="${1}"
	local dict_file="${2}"

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	echo "${dict_file} :: ${vocab_file}"
	cut -f1 "${vocab_file}" | vocab2lex-fi.pl >"${dict_file}"
	if grep '<w>' "${vocab_file}" >/dev/null
	then
		sed -i 's/^<w>.*$/<w>(1.0) __/' "${dict_file}"
		sed -i '/^__/d' "${dict_file}"
	fi
}

# Prunes n-grams from a language model. We're using IRSTLM, because SRILM seems
# to crash with big LMs!
prune_kn () {
	local threshold="${1:-1e-9}"

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }
	[ -n "${EXPT_NAME}" ] || { echo "EXPT_NAME required." >&2; exit 1; }
	[ -n "${EXPT_PARAMS}" ] || { echo "EXPT_PARAMS required." >&2; exit 1; }

	local ngram_order="${NGRAM_ORDER:-4}"
	local full_model_file="${EXPT_WORK_DIR}/kn.arpa"
	[ -s "${full_model_file}" ] || full_model_file="${EXPT_WORK_DIR}/kn.arpa.gz"
	local pruned_model_file="${EXPT_WORK_DIR}/kn-prune=${threshold}.arpa"
	echo "${pruned_model_file} :: ${full_model_file}"
	(set -x; prune-lm --threshold="${threshold}" "${full_model_file}" "${pruned_model_file}")
}

# Converts Kneser-Ney models to binary format and creates a pronunciation
# dictionary.
convert_kn () {
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }
	[ -n "${EXPT_NAME}" ] || { echo "EXPT_NAME required." >&2; exit 1; }
	[ -n "${EXPT_PARAMS}" ] || { echo "EXPT_PARAMS required." >&2; exit 1; }

	local model_file="${EXPT_WORK_DIR}/kn.arpa"
	local model_bin_file="${EXPT_WORK_DIR}/kn.fsabin"
	[ -s "${model_file}" ] || model_file="${EXPT_WORK_DIR}/kn.arpa.gz"
	[ -s "${model_file}" ] || { echo "Model file not found." >&2; exit 1; }

	local lookahead_file="${EXPT_WORK_DIR}/kn-lookahead.arpa"
	local lookahead_bin_file="${EXPT_WORK_DIR}/kn-lookahead.bin"
	local dict_file="${EXPT_WORK_DIR}/kn.lex"

	echo "${lookahead_file} :: ${model_file}"
	ngram -order 2 -lm "${model_file}" -write-lm "${lookahead_file}"

	binarize "${model_file}" "${lookahead_file}" "${model_bin_file}" "${lookahead_bin_file}"

	local vocab_file="${EXPT_WORK_DIR}/kn.vocab"
	awk '/\\1-grams:/{ unigrams=1; next }/\\/{ unigrams=0 }
             unigrams &&
	     $2 != "" &&
	     $2 != "<s>" &&
	     $2 != "</s>" &&
	     $2 != "<unk>" { print $2 }' "${lookahead_file}" \
	  >"${vocab_file}"
	create_dictionary "${vocab_file}" "${dict_file}"

	echo "convert_kn finished."
}
