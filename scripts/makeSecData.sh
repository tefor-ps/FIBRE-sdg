#!/bin/bash

#IMAGE DETECTION
if [[ -z $1 ]]; then
	error "ERROR: provide raw image to this script. Exiting."
	exit
else
	img=$(realpath $1)
	dbg $img
fi

# set all global variables
source getVar
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
trap 'echo "Cleaning up"; rm -f "$lock"; exit' INT TERM EXIT

# write image metadata to file
meta=$(sudo bash $MAKEMETA $img |tail -1)
#get number of channels from metadata
chNum=$(grep SizeC $meta |tail -1 |awk '{print $NF}')

sudo bash $MAKECALLER $img

# check if the output images already exist
status=0
for i in $(grep save $CALLER |cut -d "," -f 2 |tr -d "\"\);"); do
	# nrrds are split into individual single-channel-images, which is not reflected in the file name provided in CALLER. 
	if [[ $(echo $i |grep -c -e ".nrrd") -gt 0 ]]; then
		#dbg "looking for nrrd"
		ibn=$(echo $i |cut -d "." -f 1)
		#dbg "ibn: $ibn"
		isuff=$(echo $i |sed "s@$ibn@@")
		#dbg "isuff: $isuff"
		for cn in $(seq 1 $chNum); do
			dbg ${ibn}-C${cn}${isuff}
			ls -l $(echo ${ibn}-C${cn}${isuff})
			status=$(($status+$?))
		done
	else
		dbg2 "$i"
		ls -l $i;
		status=$(($status+$?))
	fi
done
dbg $status

if [[ $status -gt 0 ]]; then
	sudo bash $FIJIONSERVER $CALLER
fi
# fix permissions of secData
bash $FIXPERMISSIONS -d $outDir
