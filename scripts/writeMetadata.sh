#!/bin/bash
<<README
This script is writing a metadata extract from the provided image file into the location of the image:
bash thisScript /somedir/image --> /somedir/imageBn.meta.txt

This script expects one parameter:
$1 = absolute path to image to be analyzed.

DEPENDENCIES: 
exiftool are installed automatically
--> https://www.sno.phy.queensu.ca/~phil/exiftool/#system
bftools are expected in $SCRIPTSDIR/bftools
--> https://docs.openmicroscopy.org/bio-formats/latest/users/comlinetools/index.html

README
#fsdb-rev-date: 260826

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

debug=3
dbg3 "$D"

#IMAGE DETECTION
if [[ -z $1 ]]; then
	error "ERROR: provide raw image to this script. Exiting."
	exit
else
	img=$(realpath $1)
	dbg $img
fi

imgDir=$(dirname $img)
dbg2 $imgDir
suff=$(basename $img |awk -F "." '{print $NF}')
dbg2 $suff
bn=$(basename $img |sed "s@.${suff}\$@@")
dbg2 $bn
outDir=${imgDir}/${bn}${SECDATA_EXT}
dbg2 $outDir
mkdir -p $outDir

# satisfying dependencies; here exiftool
if [[ $(which exiftool |wc -l) -eq 0 ]];then
	msg "exiftool is a prerequisite for these scritps but it is not yet installed on this computer. \n Installing it now.\n"
	sudo apt install -y exiftool
fi
# satisfying dependencies; here bftool
if [[ $(ls -l $SCRIPTSDIR/bftools/showinf |wc -l 2>/dev/null) -eq 0 ]];then
	msg "bioformats is a prerequisite for these scritps but it is not yet installed on this computer. \n Installing it now.\n" 
	TMP=$(mktemp -d)
	cd $TMP
	pwd
	URL=https://downloads.openmicroscopy.org/bio-formats/latest/artifacts/bftools.zip
	wget $URL -o $TMP/log.txt
# Jan 2026, fixing server-side redirect misconfiguration at https://downloads.openmicroscopy.org/ 
	if [[ $(file bftools.zip* |grep -c "ASCII") -gt 0 ]]; then
		rm bftools.zip
		v=$(grep -e "/[0-9].[0-9].[0-9]/" log.txt |tail -1 |sed -n 's@.*\(/[0-9].[0-9].[0-9]/\)@\1@p')
		wget $(echo $URL |sed "s@/latest/@$v@")
	fi
	unzip bftools.zip
	mv bftools $SCRIPTSDIR
	cd -
	rm -rf $TMP
fi
chmod -R 750 $SCRIPTSDIR/bftools

#	IMG=${1//\\//} #replace backslashes: https://superuser.com/a/1068082
#	DL=$(echo $IMG |cut -d ":" -f 1)
#	dl=$(echo $DL | tr '[:upper:]' '[:lower:]')
#	IMG=$(echo $IMG |sed "s@${DL}:@/mnt/${dl}@")

#	bn=$(basename $IMG |cut -d "." -f 1)
#	dn=$(dirname $IMG)
#	outFile=$dn/$bn.meta.txt
outFile=$outDir/$bn.meta.txt

# increase java heap size (default 512m) to 2g to prevent crash
#https://docs.openmicroscopy.org/bio-formats/6.2.0/users/comlinetools/#command-line-environment
export BF_MAX_MEM=2g

# Bio-Formats' command-line wrapper invokes `java` from PATH. Load Fiji's
# bundled Java as a fallback without overriding an existing system Java.
FIJI_JAVA_HELPER="${thisDir}/configureFijiJava.sh"
if [[ ! -f "$FIJI_JAVA_HELPER" ]]; then
	error "Cannot find Fiji Java helper: $FIJI_JAVA_HELPER"
	exit 1
fi
if ! source "$FIJI_JAVA_HELPER"; then
	error "Could not load Fiji Java helper: $FIJI_JAVA_HELPER"
	exit 1
fi
if ! configureFijiJava; then
	error "Could not configure Fiji's bundled Java runtime."
	exit 1
fi

spacer="\n------------------------\n"
printf "${spacer}bftools metadata for $(basename $img)${spacer}" >$outFile 
bash $SCRIPTSDIR/bftools/showinf -nopix $img |grep -v "Parsing block" >> $outFile

printf "${spacer}exiftool metadata for $(basename $img)${spacer}" >>$outFile 
exiftool $img >> $outFile

# pass $outFile back to calling script for variable asignment and direct usage.
echo $outFile
