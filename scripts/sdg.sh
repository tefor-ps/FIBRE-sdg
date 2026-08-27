#!/bin/bash
<<README


README

# get location of this script
thisDir=$(dirname $(realpath "$0"))

# get variables of fsdb from getVar.sh
if ! source getVar; then
	dir=$thisDir 
	for _ in $(seq 1 4); do
		GV=$(find "$dir" -name "getVar.sh" -print -quit)
		if [[ -f $GV ]]; then 
			source "${GV}"
			break 
		else
			dir="$(dirname "$dir")"
		fi
	done
	if [[ ! -f "${GV}" ]]; then
		echo "ERROR: Can't find getVar.sh"
		exit 555
	fi
fi
intro $(basename $0)

#debug=2

dbg "TESTVAR, debug-level 1: $TESTVAR"  # demo-output for debug-level 1 
dbg2 "TESTDIR, debug-level 2: $TESTDIR" # demo-output for debug-level 2

#\\


#$FIJIONSERVER /mnt/c/Users/teforadmin/tps/gitlab/dev-dir/fsdb-sdg/scripts/Fiji.app/macros/fsdb.fsdb-sdg/alive.ijm
#$FIJIONSERVER /mnt/c/Users/teforadmin/tps/gitlab/dev-dir/secDataGeneration/scripts/Fiji.app/macros/sdg/alive.ijm
#$FIJIONSERVER "$thisDir/../Fiji.app/macros/fsdb.sdg/alive.ijm"
#$FIJIONSERVER "$(find "$(realpath "$thisDir/../Fiji.app")" -name alive.ijm)"

#<<INACTIVE
if [[ "$(file --brief -i "$1" |cut -d "/" -f 2 |cut -d ";" -f 1)" == "octet-stream"  ]]; then
	echo "processing image $1"
	$FIJIONSERVER "$(realpath "$thisDir/../Fiji.app/macros/fsdb.sdg/iterate.ijm")" "$1"

elif [[ "$(file --brief -i "$1" |cut -d "/" -f 2 |cut -d ";" -f 1)" == "plain"  ]]; then
	echo "processing content of $1:"
	cat "$1"
	cat "$1" |while read i; do 
		$FIJIONSERVER "$(realpath "$thisDir/../Fiji.app/macros/fsdb.sdg/iterate.ijm")" "$i"
	done

elif [[ "$(file --brief -i "$1" |cut -d "/" -f 2 |cut -d ";" -f 1)" == "directory"  ]]; then
	echo "processing raw data in $1:"
	find $1 -type f -name "*nd2"
	find $1 -type f -name "*nd2" |while read -r i; do 
		$FIJIONSERVER "$(realpath "$thisDir/../Fiji.app/macros/fsdb.sdg/iterate.ijm")" "$i"
	done

else 
	echo "ERROR: can not decipher $1. Exiting."
	exit

fi

#INACTIVE