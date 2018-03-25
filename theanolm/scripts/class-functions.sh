#!/bin/bash -e
#
# Helper functions for classifying words.

source "${PROJECT_SCRIPT_DIR}/defs.sh"

lm_tools_dir="${HOME}/git/senarvi-speech/lm-tools"
clss_dir="${PROJECT_DIR}/opt/clss"


classes_freq () {
	[ -n "${NUM_CLASSES}" ] || { echo "NUM_CLASSES required." >&2; exit 1; }
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	mkdir -p "${EXPT_WORK_DIR}"

	local counts_file="${EXPT_WORK_DIR}/word.1cnt"
	cat "${TRAIN_FILES[@]}" |
	  ngram-count -order 1 -no-sos -no-eos -text - -write "${counts_file}"

	local total_words=$(wc -l <"${counts_file}")
	local words_per_class=$(((total_words + NUM_CLASSES - 1) / NUM_CLASSES))
	sort -n -k2,2 "${counts_file}" |
	  split --lines="${words_per_class}" -a 4 -d - "${EXPT_WORK_DIR}/counts.part"

	declare -a part_files
	part_files=("${EXPT_WORK_DIR}/counts.part"*)
	part_files=($(printf '%s\n' "${part_files[@]}" | sort))

	local class=0
	for part_file in "${part_files[@]}"
	do
		awk -v "class=${class}" '{ print $1, class }' "${part_file}"
		class=$((class + 1))
	done >"${EXPT_WORK_DIR}/classes"

	rm -f "${part_files[@]}"
	echo "classes_freq finished."
}


classes_mkcls () {
	[ -n "${NUM_CLASSES}" ] || { echo "NUM_CLASSES required." >&2; exit 1; }
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	local num_iterations="${NUM_ITERATIONS:-1}"

	declare -a extra_args
	[ -n "${READ_CLASSES}" ] && extra_args+=(-iother "${READ_CLASSES}")

	local max_seconds=430000  # 5 days
	(( NUM_ITERATIONS > 1 )) && max_seconds=1290000  # 15 days

	mkdir -p "${EXPT_WORK_DIR}"

	local train_all_file="${EXPT_WORK_DIR}/train.txt"
	cat "${TRAIN_FILES[@]}" >"${train_all_file}"

	# -r1 = random seed
	(set -x; mkcls -c"${NUM_CLASSES}" \
	  -n"${num_iterations}" \
	  -p"${train_all_file}" \
	  -V"${EXPT_WORK_DIR}/classes" \
	  -r1 \
	  -s"${max_seconds}" \
	  "${extra_args[@]}")
	echo "classes_mkcls finished."
}


classes_exchange () {
	if [ -n "${1}" ]
	then
		declare -a train_files=("${!1}")
	else
		declare -a train_files=("${TRAIN_FILES[@]}")
	fi

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	local num_classes="${NUM_CLASSES:-2000}"
	local num_threads="${NUM_THREADS:-4}"
	local max_seconds="${EXCHANGE_MAX_SECONDS:-430000}"  # Default time limit 5 days.

	command -v exchange >/dev/null 2>&1 || { echo >&2 "exchange not found. Have you loaded exchange module?"; exit 1; }

	declare -a extra_args

	mkdir -p "${EXPT_WORK_DIR}"

	local temp_file=$(ls -1 "${EXPT_WORK_DIR}"/exchange.temp*.classes.gz 2>/dev/null |
	                  sort -V |
	                  tail -1)
	if [ -s "${temp_file}" ]
	then
		echo "Continuing from ${temp_file}."
		extra_args+=(--class-init="${temp_file}")
	elif [ -n "${READ_CLASSES}" ]
	then
		extra_args+=(--class-init="${READ_CLASSES}")
	fi

	local train_all_file="${EXPT_WORK_DIR}/train.txt"
	cat "${train_files[@]}" >"${train_all_file}"

	local vocab_file="${EXPT_WORK_DIR}/cluster.vocab"
	if [ -n "${CLUSTER_VOCAB_SIZE}" ]
	then
		select_vocabulary "${vocab_file}" "${CLUSTER_VOCAB_SIZE}" "${DEVEL_FILE}" "${train_files[@]}"
	else
		ngram-count -order 1 -text "${train_all_file}" -no-sos -no-eos -write-vocab - |
		  sort |
		  grep -v '<unk>' \
		  >"${vocab_file}"
	fi

	(set -x; exchange \
	  --num-classes="${num_classes}" \
	  --max-time="${max_seconds}" \
	  --num-threads="${num_threads}" \
	  --vocabulary="${vocab_file}" \
	  "${extra_args[@]}" \
	  "${train_all_file}" \
	  "${EXPT_WORK_DIR}/exchange")

	rm -f "${train_all_file}" "${EXPT_WORK_DIR}"/exchange.temp*
	echo "classes_exchange finished."
}


classes_brown () {
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	local num_classes="${NUM_CLASSES:-2000}"
	local num_threads="${NUM_THREADS:-1}"

	mkdir -p "${EXPT_WORK_DIR}"

	local train_all_file="${EXPT_WORK_DIR}/train.txt"
	cat "${TRAIN_FILES[@]}" >"${train_all_file}"

	local vocab_file="${EXPT_WORK_DIR}/cluster.vocab"
	local comment
	if [ -n "${CLUSTER_VOCAB_SIZE}" ]
	then
		select_vocabulary "${vocab_file}" "${CLUSTER_VOCAB_SIZE}" "${DEVEL_FILE}" "${TRAIN_FILES[@]}"
		comment="vocab=${CLUSTER_VOCAB_SIZE}-n=${num_classes}"
	else
		ngram-count -order 1 -text "${train_all_file}" -no-sos -no-eos -write-vocab - |
		  sort |
		  grep -v '<unk>' \
		  >"${vocab_file}"
		comment="n=${num_classes}"
	fi

	(set -x; wcluster \
	  --c "${num_classes}" \
	  --rand 1 \
	  --threads "${num_threads}" \
	  --text "${train_all_file}" \
	  --restrict "${vocab_file}" \
	  --output_dir "${EXPT_WORK_DIR}/output" \
	  --paths "${EXPT_WORK_DIR}/paths" \
	  --map "${EXPT_WORK_DIR}/map" \
	  --collocs "${EXPT_WORK_DIR}/collocs" \
	  --comment "${comment}")

	rm -f "${train_all_file}"
	echo "classes_brown finished."
}


classes_word2vec () {
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	local num_classes="${NUM_CLASSES:-2000}"
	local num_neurons="${NUM_NEURONS:-200}"
	local num_iterations="${NUM_ITERATIONS:-15}"
	local window="${WINDOW:-8}"
	local min_count="${MIN_COUNT:-1}"
	local num_threads="${NUM_THREADS:-2}"

	mkdir -p "${EXPT_WORK_DIR}"

	local train_all_file="${EXPT_WORK_DIR}/train.txt"
	cat "${TRAIN_FILES[@]}" >"${train_all_file}"

	declare -a extra_args

	if [ "${ALGORITHM}" = "SKIPGRAM" ] || [ -z "${ALGORITHM}" ]
	then
		extra_args+=(-cbow 0)
	elif [ "${ALGORITHM}" = "CBOW" ]
	then
		extra_args+=(-cbow 1)
	else
		echo "Invalid ALGORITHM (${ALGORITHM})." >&2
		exit 1
	fi

	local counts_file="${EXPT_WORK_DIR}/cluster.1cnt"
	if [ -n "${CLUSTER_VOCAB_SIZE}" ]
	then
		local vocab_file="${EXPT_WORK_DIR}/cluster.vocab"
		select_vocabulary "${vocab_file}" "${CLUSTER_VOCAB_SIZE}" "${DEVEL_FILE}" "${TRAIN_FILES[@]}"

		# We need to use the actual counts instead of the weighted ones.
		set -x
		word2vec -train "${train_all_file}" -min-count 1 -save-vocab "${counts_file}.tmp"
		awk 'NR==FNR{ a[$1]; next } ($1 in a){ print $1 "\t" $2 }' "${vocab_file}" "${counts_file}.tmp" >"${counts_file}"
		set +x
		rm -f "${counts_file}.tmp"
	else
		ngram-count -order 1 -text "${train_all_file}" -no-sos -no-eos -write - |
		  sort |
		  grep -v '<unk>' \
		  >"${counts_file}"
	fi

	# Strange corruption in file name occurred with more complicated names.
	(set -x; word2vec \
	  -train "${train_all_file}" \
	  -read-vocab "${counts_file}" \
	  -output "${EXPT_WORK_DIR}/classes" \
	  -size "${num_neurons}" \
	  -window "${window}" \
	  -negative 25 \
	  -hs 0 \
	  -min-count "${min_count}" \
	  -sample 1e-4 \
	  -threads "${num_threads}" \
	  -iter "${num_iterations}" \
	  -classes "${num_classes}" \
	  "${extra_args[@]}")

	rm -f "${train_all_file}"
	echo "classes_word2vec finished."
}


train_clss () {
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	local tokens_per_word="${TOKENS_PER_WORD:-50}"
	local beam="${CLSS_BEAM:-10.0}"
	local final_tokens="${FINAL_TOKENS:-50}"
	local num_threads="${NUM_THREADS:-4}"

	mkdir -p "${EXPT_WORK_DIR}"

	local train_all_file="${EXPT_WORK_DIR}/train.txt"
	cat "${TRAIN_FILES[@]}" >"${train_all_file}"

	if [ ! -f "${EXPT_WORK_DIR}/words.txt" ]
	then
		echo "${EXPT_WORK_DIR}/words.txt :: ${train_all_file}"
		"${clss_dir}/getwords.py" <"${train_all_file}" |
		  awk '{ print toupper(substr($0,1,1)) tolower(substr($0,2));
		         print tolower($0) }' \
		  >"${EXPT_WORK_DIR}/words.txt"
	fi

	if [ ! -f "${EXPT_WORK_DIR}/words.analysis" ]
	then
		echo "${EXPT_WORK_DIR}/words.analysis :: ${EXPT_WORK_DIR}/words.txt"
		omorfi-analyse-tokenised.sh <"${EXPT_WORK_DIR}/words.txt" |
		  grep -v 'inf$' |
		  grep -v '^$' |
		  awk '{ print tolower(substr($0, 1, 1)) substr($0, 2) }' \
		  >"${EXPT_WORK_DIR}/words.analysis"
	fi

	if [ ! -f "$EXPT_DIR/words.init" ]
	then
		echo "${EXPT_WORK_DIR}/words.init :: ${EXPT_WORK_DIR}/words.analysis"
		"${clss_dir}/omorfi_init_words.py" "${EXPT_WORK_DIR}/words.analysis" \
		  >"${EXPT_WORK_DIR}/words.init"
	fi

	echo "${EXPT_WORK_DIR}/model.*.gz :: ${EXPT_WORK_DIR}/words.init"
	(set -x; "${clss_dir}/train2" \
	  -o "${tokens_per_word}" \
	  -b "${beam}" \
	  -t "${num_threads}" \
	  -l 60 \
	  -f "${final_tokens}" \
	  -c 5 \
	  "${EXPT_WORK_DIR}/words.init" \
	  "${train_all_file}" \
	  "${EXPT_WORK_DIR}/model.clss")

	rm -f "${train_all_file}"
	echo "train_clss finished."
}


apply_clss () {
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	for in_file in "${TRAIN_FILES[@]}"
	do
		local basename="$(basename ${in_file} .txt)"
		local out_file="${EXPT_WORK_DIR}/${basename}.classes.txt.gz"
		echo "${out_file} :: ${in_file}"
		(set -x; "${clss_dir}/classseq" \
		  -p 1 \
		  "${EXPT_WORK_DIR}/model.clss.ngram.gz" \
		  "${EXPT_WORK_DIR}/model.clss.classes.gz" \
		  "${EXPT_WORK_DIR}/model.clss.words.gz" \
		  "${in_file}" \
		  "${out_file}")
	done

	echo "apply_clss finished."
}


fix_class_probabilities () {
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	mkdir -p "${EXPT_WORK_DIR}"

	local in_classes="${EXPT_WORK_DIR}/classes"
	local counts_file
	local out_classes
	if [ -n "${VOCAB_SIZE}" ]
	then
		out_classes="${EXPT_WORK_DIR}/classes-vocab=${VOCAB_SIZE}.sricls"
		counts_file="${EXPT_WORK_DIR}/word-${VOCAB_SIZE}.1cnt"
		if [ ! -s "${counts_file}" ]
		then
			echo "${counts_file}"
			select_vocabulary_with_counts "${counts_file}" "${VOCAB_SIZE}" "${DEVEL_FILE}" "${TRAIN_FILES[@]}"
		fi
	else
		out_classes="${EXPT_WORK_DIR}/classes.sricls"
		counts_file="${EXPT_WORK_DIR}/word.1cnt"
		if [ ! -s "${counts_file}" ]
		then
			echo "${counts_file}"
			cat "${TRAIN_FILES[@]}" |
			  ngram-count -order 1 -no-sos -no-eos -text - -write "${counts_file}"
		fi
	fi

	echo "${out_classes} :: ${in_classes}"
	"${lm_tools_dir}/fix-class-probabilities.py" "${in_classes}" "${counts_file}" |
	  grep -v ' 0.0 ' >"${out_classes}"
}
