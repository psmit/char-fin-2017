#!/bin/bash -e

test_set="${1}"
shift

script_dir=$(readlink -f "$(dirname $0)")
project_dir="${script_dir}/.."

references="${project_dir}/data/${test_set}/normalized.trn"

references_8bit=$(mktemp ${TMPDIR}/$(basename "$0").XXXXXXXXXX)
iconv -f UTF-8 -t ISO-8859-15 <${references} >"${references_8bit}"

for hypothesis in "${@}"
do
	if [ ! -e "${hypothesis}" ]
	then
		echo "Hypothesis file does not exist: ${hypothesis}" 2>&1
		exit 1
	fi

	hypothesis_8bit=$(mktemp --tmpdir $(basename "${0}").XXXXXXXXXX)
	iconv -f UTF-8 -t ISO-8859-15 <"${hypothesis}" >"${hypothesis_8bit}"

	dir=$(dirname "${hypothesis}")
	name=$(basename "${hypothesis}" .trn)
	echo "${name}"
	sclite -i wsj -f 0 -h "${hypothesis_8bit}" -r "${references_8bit}" -p |
	  iconv -f ISO-8859-15 -t UTF-8 |
	  sed -r 's/^<PATH id="([^"]*)" .*$/\n\1/' |
	  grep -v '^<' |
	  sed -r 's/C,"[^"]*","[^"]*"//g' |
	  sed -r 's/S,"([^"]*)","([^"]*)"/\n\1 -> \2/g' |
	  sed -r 's/D,"([^"]*)",/\n\1 -/g' |
	  sed -r 's/I,,"([^"]*)"/\n\1 +/g' |
	  sed -r 's/:+$//' \
	  >"${dir}/${name}.errors"
	rm -f "${hypothesis_8bit}"
done

rm -f "${references_8bit}"
