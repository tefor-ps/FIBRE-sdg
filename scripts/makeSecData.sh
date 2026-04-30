#!/bin/bash

#IMAGE DETECTION
if [[ -z $1 ]]; then
	error "ERROR: provide raw image to this script. Exiting."
	exit
else
	img=$(realpath $1)
	echo "Image: $(basename $img)"
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
debug=3

imgDir=$(dirname $img)
dbg2 $imgDir
suff=$(basename $img |awk -F "." '{print $NF}')
dbg2 $suff
bn=$(basename $img |sed "s@.${suff}\$@@")
dbg2 $bn
lock=$imgDir/$bn.lock
date>$lock
outDir=${imgDir}/${bn}${SECDATA_EXT}
dbg2 $outDir
mkdir -p $outDir

# ensure lock file is removed when not needed anymore
trap 'echo "Cleaning up"; rm -f "$lock"' INT TERM EXIT

# write image metadata to file
meta=$(sudo bash $MAKEMETA $img |tail -1)
#get number of channels from metadata
chNum=$(grep SizeC $meta |tail -1 |awk '{print $NF}')

# create CALLEr macro
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
		ls -l $i;
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
