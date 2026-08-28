#!/bin/bash
<<README
This script converts a series of numbered pngs into a movie in mp4 format.

mode of function and prerequisits
Provide first (or any) frame of movie (something.0000.something_else.suffix)
frames need to be numbered with 3 leading zeros (e.g.0001). 
The numbering can be anywhere within the file name and can be prefixed with any string.
The numbering must be followed by one of the folllowing puctuation signs (.-_)
$2: optionally a height in pixels of the movie can be provided (e.g. 720 for results in 720p)
$3: optionally a frame rate; default 24fps
$4: optionally a boolean can toggle overwrite (default 0)
$5: optionally a boolean can toggle the insertion of a logo (default 1)

Requirements:
ffmpeg, imagemagick

README

usage(){
	printf "
	\$1: first frame of movie
	\$2: height-limit; default org. type 'org' if needed.
	\$3: frame rate; default: 24fps -- doesn't change anything
	\$4: overwrite exitsing file (1/0); default 0
	\$5: display logo (1/0); default 1
	"
	echo
}

if [[ -z $1  ]]; then
	usage
	exit
fi

#============================
# define variables and generate directories as needed
#============================
# set all global variables
thisDir=$(dirname  $0)
source $thisDir/getVar.sh

intro $0

dbg "starting ..."

# timestamp for index files
D=$(date +%y%m%d)

# log file for debugging and cleanup
mkdir -p $LOGDIR
LOG="$LOGDIR/$D.$(basename $0 .sh).log"
dbg2 "logs at $LOGDIR/$LOG"
if [ -f $LOG ]; then
	sudo rm $LOG
fi
date >$LOG

if [[ -z $2 || "$2" = "org" ]]; then
	height=0
else
	height=$2
fi
if [[ -z $3 ]]; then
	frameRate=24
else
	frameRate=$3
fi
if [[ -z $4 ]]; then
	overwrite=0
else
	overwrite=$4
fi
if [[ -z $5 ]]; then
	displayLogo=1
else
	displayLogo=$5
fi

div=15		#default 10
suff=mp4	#sticking to mp4 since mpg looks horrible.



if [ ! -f $LOGO ]; then
	error "$LOGO does not exists on this system. Omitting overlay."
	displayLogo=0
fi 

dbg $1 $2 $3 $4 $5

makeMovie() {
	dbg "makeMovie" |tee -a $LOG
#	frameRate=24 #default 24
	if [[ $displayLogo -eq 1 ]]; then
		dbg "A" |tee -a $LOG
		if [[ $height -gt 0 ]]; then
			dbg "AA" |tee -a $LOG
# trick of adding </dev/null learned from https://stackoverflow.com/a/16527559						
			#ffmpeg -loglevel debug -report -r $frameRate -i $string -i $LOGO  -filter_complex "[0:v]scale=trunc\(oh*a/2\)*2:$height[bckg];[1:v]scale=\($height/$div\):\($height/a\)/$div[ovrl],[bckg][ovrl]overlay=main_w-overlay_w-10:main_h-overlay_h-10[v]" -map "[v]"  $outFile < /dev/null 2>&1 |tee -a $LOG 
			ffmpeg -r $frameRate -i $string -i $LOGO  -filter_complex "[0:v]scale=trunc\(oh*a/2\)*2:$height[bckg];[1:v]scale=\($height/$div\):\($height/a\)/$div[ovrl],[bckg][ovrl]overlay=main_w-overlay_w-10:main_h-overlay_h-10[v]" -map "[v]"  $outFile < /dev/null 2>&1 |tee -a $LOG 
		else
			if [[ "$1" == "W" ]]; then
				dbg "ABA" |tee -a $LOG
				#ffmpeg -loglevel debug -report -r $frameRate -i $string -i $LOGO -filter:v  -filter_complex "[0:v]scale=trunc(iw/2)*2:trunc(ih/2)*2[bckg];[1:v]scale=\($W/$div\)*a:$W/$div[ovrl],[bckg][ovrl]overlay=main_w-overlay_w-10:main_h-overlay_h-10[v]" -map "[v]" $outFile < /dev/null 2>&1 |tee -a $LOG
				ffmpeg  -r $frameRate -i $string -i $LOGO -filter:v  -filter_complex "[0:v]scale=trunc(iw/2)*2:trunc(ih/2)*2[bckg];[1:v]scale=\($W/$div\)*a:$W/$div[ovrl],[bckg][ovrl]overlay=main_w-overlay_w-10:main_h-overlay_h-10[v]" -map "[v]" $outFile < /dev/null 2>&1 |tee -a $LOG
			else
				dbg "ABB" |tee -a $LOG
				#ffmpeg -loglevel debug -report -r $frameRate -i $string -i $LOGO -filter_complex "[0:v]scale=trunc(iw/2)*2:trunc(ih/2)*2[bckg];[1:v]scale=\($H/$div\)*a:$H/$div[ovrl],[bckg][ovrl]overlay=main_w-overlay_w-10:main_h-overlay_h-10[v]" -map "[v]" $outFile < /dev/null 2>&1 |tee -a $LOG
#				ffmpeg -r $frameRate -i $string -i $LOGO -filter_complex "[0:v]scale=trunc(iw/2)*2:trunc(ih/2)*2[bckg];[1:v]scale=\($H/$div\)*a:$H/$div[ovrl],[bckg][ovrl]overlay=main_w-overlay_w-10:main_h-overlay_h-10[v]" -map "[v]" $outFile < /dev/null 2>&1 |tee -a $LOG
				ffmpeg -r $frameRate -i $string -i $LOGO -filter_complex "[0:v]scale=trunc(iw/2)*2:trunc(ih/2)*2[bckg];[1:v]scale=\($H/$div\)*a:$H/$div[ovrl],[bckg][ovrl]overlay=main_w-overlay_w-10:main_h-overlay_h-10[v]" -map "[v]" $outFile < /dev/null 2>&1 |tee -a $LOG

			fi
		fi
	else
		dbg "B" |tee -a $LOG
		if [[ $height -gt 0 ]]; then
			dbg "BA" |tee -a $LOG
			#ffmpeg -loglevel debug -report -r $frameRate -i $string -vf scale="trunc\(oh*a/2\)*2:$height"  $outFile < /dev/null 2>&1 |tee -a $LOG
			ffmpeg -report -r $frameRate -i $string -vf scale="trunc\(oh*a/2\)*2:$height"  $outFile < /dev/null 2>&1 |tee -a $LOG
		else
			dbg "BB" |tee -a $LOG
			#ffmpeg -loglevel debug -report -r $frameRate -i $string -vf scale="trunc\(iw/2\)*2:trunc\(ih/2\)*2" $outFile < /dev/null 2>&1 |tee -a $LOG
			ffmpeg -r $frameRate -i $string -vf scale="trunc\(iw/2\)*2:trunc\(ih/2\)*2" $outFile < /dev/null 2>&1 |tee -a $LOG
		fi
	fi
	msg "film written to \n$outFile\n"
}

input=$1
if [[ ! -f $input ]]; then
	error "$input is not a file. \nPlease provide the first image of the stack."
	exit
fi
dn=$(dirname $input)
#bn=$(basename $input |sed 's@[[:punct:]][Z]*[[:digit:]]\{4\}@@' |rev |cut -d "." -f 2- |rev)
insuff=$(echo $input |awk -F "." '{print $NF}')
bn=$(basename $input |sed "s@[[:punct:]]*\.[[:digit:]]\{4\}\.$insuff@@")
string=$(echo $input |sed 's@\(.*\)[[:digit:]]\{4\}[[:punct:]]@\1%04d_@' |sed "s@_$insuff@\.$insuff@")

dbg "basename: $bn"
dbg "string: $string"
outDir=$dn/..
W=$(identify $input |cut -d " " -f 3 |cut -d "x" -f 1)
H=$(identify $input |cut -d " " -f 3 |cut -d "x" -f 2)
if [[ $height -gt 0 ]]; then
	outFile=$outDir/${bn}.${height}p.${frameRate}fps.$suff
else
	outFile=$outDir/${bn}.${frameRate}fps.$suff
fi
if [ ! -d $outDir ]; then
	mkdir -p $outDir
fi

if [[ ! -f $outFile ]]; then
		makeMovie
else
	if [[ $overwrite -eq 1 ]]; then
		rm $outFile
		if [[ $H -gt $W ]]; then
			makeMovie W
		else
			makeMovie H
		fi
	else
		printf "$outFile already exists. Skipping."
		usage
	fi
fi
