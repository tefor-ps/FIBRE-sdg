#!/bin/bash

# ensure correct reporting of failures within pipes
set -o pipefail

## =====================
## DEFINITION OF HELP FUNCTION
## =====================

function usage() {
<<readme
INFO
CALL
INPUT
OUTPUT
readme
		printf "\nUsage: sudo bash $0 [-h] file
		" 1>&2
	exit 1
}

while getopts "h" opt; do
	printf "Option -$opt was triggered. " >&2 
	case $opt in
		h)
			usage
			echo
			;;
	esac
done
shift $((OPTIND-1))
			

#IMAGE DETECTION
if [[ ! -f "$1" ]]; then
	echo "ERROR: $1 is not a file."
	usage
else
	img=$(realpath $1)
	printf  "\tImage: $(basename $img)\n"
	imgDir=$(dirname $img)
	suff=$(basename $img |awk -F "." '{print $NF}')
	bn=$(basename $img |sed "s@.${suff}\$@@")
	lock=$imgDir/$bn.lock
	if [[ -f $lock ]]; then
		echo "ERROR: $1 locked. Skipping."
		exit
	else
		date>$lock
	fi
fi

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

# define local debug level (overwrites global one). Comment out to follow global debug level.
#debug=3


outDir=${imgDir}/${bn}${SECDATA_EXT}
dbg2 $outDir
mkdir -p $outDir

# ensure lock file is removed when not needed anymore
trap 'echo "Cleaning up"; rm -f "$lock"' INT TERM EXIT

# write image metadata to file
meta=$(sudo bash $MAKEMETA $img |tail -1)
#get number of channels from metadata
chNum=$(grep SizeC $meta |tail -1 |awk '{print $NF}')

# create CALLER macro
sudo bash $MAKECALLER $img

# check if the output images already exist
status=0
for i in $(grep save $CALLER |cut -d "," -f 2 |tr -d "\"\);"); do
	dbg2 $i
	# nrrds are split into individual single-channel-images, which is not reflected in the file name provided in CALLER. 
	if [[ $(echo $i |grep -c -e ".nrrd") -gt 0 ]]; then
		dbg2 "looking for nrrd"
		ibn=$(echo $i |cut -d "." -f 1)
		dbg2 "ibn: $ibn"
		isuff=$(echo $i |sed "s@$ibn@@")
		dbg2 "isuff: $isuff"
		for cn in $(seq 1 $chNum); do
			dbg ${ibn}-C${cn}${isuff}
			ls -l $(echo ${ibn}-C${cn}${isuff})
			status=$(($status+$?))
		done
#read ans
	else
		dbg2 "$i"
		ls -l $i
		status=$(($status+$?))
	fi
done
dbg $status
# run CALLER macro in fiji (on server)
if [[ $status -gt 0 ]]; then
	sudo bash $FIJIONSERVER $CALLER
fi
# fix permissions of secData
bash $FIXPERMISSIONS -d $outDir
