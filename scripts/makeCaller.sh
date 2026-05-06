#!/bin/bash

#TODO: potentially populate IJ.prefs.set into CALLER?

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
debug=0

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

call="${call}\nrun(\"Close All\");"
call="${call}\nprint(\"\\\\\\Clear\");"
call="${call}\nrun(\"Bio-Formats Importer\", \"open=$img autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT\");"
call="${call}\nIID=getImageID();"

suff=""

# IMAGE PREPROCESSING (COLOR-CORRECTION)
if [[ $(grep GLOBAL_PPTOG $CONFIG |awk -F "|" '{print $3}') -eq 1 ]]; then
	ppsuff=$suff
	for cat in PPTOG ; do
		for i in $(grep ${cat} $CONFIG |cut -d " " -f 1|grep -v -e "#" -e GLOBAL); do
			tog=$(grep $i $CONFIG |awk -F "|" '{print $3}')
			dbg "PPtog: $i $tog"
			if [[ $tog -eq 1 ]]; then
				task=$(echo $i |cut -d "_" -f 1)
				macro=$(eval echo $(grep $task $CONFIG |grep -v -e "#" |grep MAC |awk -F "|" '{print $3}'))
				if [[ -f $macro ]]; then
					call="${call}\n\nselectImage(IID);"
					ppsuff=${ppsuff}$(grep $task $CONFIG |grep -v -e "#" |grep SUFF |awk -F "|" '{print $3}'|tr -d " ")
					call="$call\nrunMacro(\"${macro}\", \"$ppsuff\");"
					call="${call}\nIID=getImageID();"
				else
					warn "ERROR: Can't find $macro. Skipping."
				fi
			fi
		done
		suff=${ppsuff}
	done
	dbg3 "ppsuff: $ppsuff"
	dbg3 "suff: $suff"
else
	dbg "PPTOG toggled off globally"
	ip="#"
	iptog=0
fi

# IMAGE MANIPULATION (CROP)
if [[ $(grep GLOBAL_IMTOG $CONFIG |awk -F "|" '{print $3}') -eq 1 ]]; then
	imcall=""
	imsuff=$suff
	for cat in IMTOG ; do
		for i in $(grep ${cat} $CONFIG |cut -d " " -f 1|grep -v -e "#" -e GLOBAL); do
			tog=$(grep $i $CONFIG |awk -F "|" '{print $3}')
			dbg "IMtog: $i $tog"
			if [[ $tog -eq 1 ]]; then
				task=$(echo $i |cut -d "_" -f 1)
				macro=$(eval echo $(grep $task $CONFIG |grep -v -e "#" |grep MAC |awk -F "|" '{print $3}'))
				if [[ -f $macro ]]; then
					imcall="${imcall}\n\nselectImage(IID);"
					tmpsuff=$(grep $task $CONFIG |grep -v -e "#" |grep SUFF |awk -F "|" '{print $3}'|tr -d " ")
					# apply suffixes with leading hyphen mutually exclusive
					if [[ $tmpsuff =~ ^- ]]; then
						imsuff=${tmpsuff}
					else
						imsuff=${imsuff}${tmpsuff}
					fi
					imcall="$imcall\nrunMacro(\"${macro}\", \"$imsuff\");"
					imcall="${imcall}\nIID=getImageID();"
				else
					warn "ERROR: Can't find $macro. Skipping."
				fi
			fi
		done
		suff=${imsuff}
	done
	tmp=$(printf "${imcall}" |tail -4) 
	call="${call}\n${tmp}\n"
	dbg3 "imsuff: $imsuff"
	dbg3 "suff: $suff"
else
	dbg3 "IMTOG toggled off globally"
	ip="#"
	iptog=0
fi

# IMAGE EXPORT (.mha, .hdf5, .nrrd)
if [[ $(grep GLOBAL_EXTOG $CONFIG |awk -F "|" '{print $3}') -eq 1 ]]; then
	excall=""
	exsuff=$suff
	for cat in EXTOG ; do
		for i in $(grep ${cat} $CONFIG |cut -d " " -f 1|grep -v -e "#" -e GLOBAL); do
			tog=$(grep $i $CONFIG |awk -F "|" '{print $3}')
			dbg "EXtog: $i $tog"
			if [[ $tog -eq 1 ]]; then
				task=$(echo $i |cut -d "_" -f 1)
				macro=$(eval echo $(grep $task $CONFIG |grep -v -e "#" |grep MAC |awk -F "|" '{print $3}'))
				if [[ $(grep $task $CONFIG |grep -v -e "#" |grep -c FT ) -gt 0 ]]; then
					ft=$(grep $task $CONFIG |grep -v -e "#" |grep FT |awk -F "|" '{print $3}' |tr -d " ")
					dbg2 "file-type: $ft"
				else
					ft=""
				fi
				if [[ -f $macro ]]; then
					excall="${excall}\nselectImage(IID);"
					exsuff=${exsuff}$(grep $task $CONFIG |grep -v -e "#" |grep SUFF |awk -F "|" '{print $3}'|tr -d " ")
					excall="$excall\nrunMacro(\"${macro}\", \"${outDir}/${bn}${exsuff}${iasuff}${sdsuff}${ft}\");"
					excall="${excall}\nIID=getImageID();"
				else
					warn "ERROR: Can't find $macro. Skipping."
				fi
			fi
		done
	done
	call="${call}\n${excall}\n"
	dbg3 "exsuff: $exsuff"
	dbg3 "suff: $suff"
else
	dbg3 "IMTOG toggled off globally"
	ip="#"
	iptog=0
fi

if [[ $(grep GLOBAL_IPTOG $CONFIG |awk -F "|" '{print $3}') -eq 1 ]]; then
	origsuff=$suff
	for ip in $(grep IPTOG $CONFIG |cut -d " " -f 1|grep -v -e "#" -e GLOBAL); do
# IMAGE PROCESSING (CONTRAST CORRECTION)		
		iptog=$(grep $ip $CONFIG |grep -v -e GLOBAL |awk -F "|" '{print $3}')
		if [[ $iptog -eq 1 ]]; then
			task=$(echo $ip |cut -d "_" -f 1)
			dbg "IPtog: $task $iptog"
			macro=$(eval echo $(grep $task $CONFIG |grep -v -e "#" |grep MAC |awk -F "|" '{print $3}'))
			if [[ ! -f $macro ]]; then
				warn "ERROR: Can't find $macro. Skipping."
			else
				ipsuff=$(grep $(echo $ip|sed 's@IPTOG@IPSUFF@')  $CONFIG |grep -v -e GLOBAL |tr -d " " |awk -F "|" '{print $3}')
				dbg3 "ipsuff: $ipsuff"
				dbg3 "suff: $suff"
				suff=${origsuff}${ipsuff}
				call="${call}\n\nselectImage(IID);"
				call="${call}\nrunMacro(\"${macro}\", \"$ipsuff\");"
				call="${call}\nIID=getImageID();"
# CREATE SECONDARY DATA	(MIP, AIP, CS, ...)
				for cat in  SDTOG ; do
					dbg2 "cat: $cat"
					if [[ $(grep GLOBAL_${cat} $CONFIG |awk -F "|" '{print $3}' |tr -d " ") -eq 1 ]]; then
						for i in $(grep ${cat} $CONFIG |cut -d " " -f 1|grep -v -e "#" -e GLOBAL); do
							dbg2 "::$i"
							tog=$(grep $i $CONFIG |awk -F "|" '{print $3}')
							task=$(echo $i |cut -d "_" -f 1)
							dbg "SDtog: $task $tog"
							if [[ $tog -eq 1 ]]; then
								call="${call}\n\nselectImage(IID);"
								dbg2 "task: $task"
								macro=$(eval echo $(grep $task $CONFIG |grep -v -e "#" |grep MAC |awk -F "|" '{print $3}'))
								if [[ ! -f $macro ]]; then
									warn "ERROR: Can't find $macro. Skipping."
								else
									dbg2 "macro: $macro"
									sdsuff=$(grep $task $CONFIG |grep -v -e "#" |grep SUFF |awk -F "|" '{print $3}'|tr -d " ")
									dbg2 "suffix: $sdsuff"
									if [[ $(grep $task $CONFIG |grep -v -e "#" |grep -c FT ) -gt 0 ]]; then
										ft=$(grep $task $CONFIG |grep -v -e "#" |grep FT |awk -F "|" '{print $3}' |tr -d " ")
										dbg2 "file-type: $ft"
									else
										ft=""
									fi
									dbg3 "sdsuff: $sdsuff"
									dbg3 "suff: $suff"
									call="$call\nrunMacro(\"${macro}\", \"${suff}${sdsuff}${ft}\");"
									
# ANNOTATE THE SECONDARY DATA (SCALEBAR, CONTRAST LEVEL)
									if [[ $(grep GLOBAL_IATOG $CONFIG |awk -F "|" '{print $3}') -eq 1 ]]; then
										iasuff=""
										#macros=()
										for cat in IATOG ; do
											for i in $(grep ${cat} $CONFIG |cut -d " " -f 1|grep -v -e "#" -e GLOBAL); do
												tog=$(grep $i $CONFIG |awk -F "|" '{print $3}')
												task=$(echo $i |cut -d "_" -f 1)
												dbg "IAtog: $task $tog"
												if [[ $tog -eq 1 ]]; then
													macro=$(eval echo $(grep $task $CONFIG |grep -v -e "#" |grep MAC |awk -F "|" '{print $3}'))
													if [[ -f $macro ]]; then
														iasuff=${iasuff}$(grep $task $CONFIG |grep -v -e "#" |grep SUFF |awk -F "|" '{print $3}'|tr -d " ")
														call="$call\nrunMacro(\"${macro}\", \"${suff}${iasuff}${sdsuff}${ft}\");"
													else
														warn "ERROR: Can't find $macro. Skipping."
													fi
												fi
											done
										done
									fi
# SAVE RESULT
									case "$ft" in
										.png)
											macro=$(eval echo $(grep SAVEPNG_MAC $CONFIG |grep -v -e "#" |awk -F "|" '{print $3}'))
											makeCall=1
											;;
										.tif)
											macro=$(eval echo $(grep SAVETIF_MAC $CONFIG |grep -v -e "#" |awk -F "|" '{print $3}'))
											makeCall=1
											;;
										.nrrd)
											macro=$(eval echo $(grep SAVENRRD_MAC $CONFIG |grep -v -e "#" |awk -F "|" '{print $3}'))
											makeCall=1
											;;									
										*)
											warn "ERROR: can't recognize output file type $ft"
											makeCall=0
											;;
									esac
									if [[ $makeCall -eq 1 && -f $macro ]]; then
										dbg "macro: $macro"
										call="$call\nrunMacro(\"${macro}\", \"${outDir}/${bn}${suff}${iasuff}${sdsuff}${ft}\");"
									fi
								fi
							fi
						done
					else
						dbg3 "cat $cat toggled off gobally"
					fi
				done
			fi
		fi
	done

# finishing the macro run
	call="${call}\n\nprint(\"Done.\");"
	call="${call}\n\nrun(\"Quit\");"
	if [[ $debug -gt 0 ]]; then
		printf "${call}\n" |tee ${CALLER}
	else
		printf "${call}\n" > ${CALLER}
	fi
else
	dbg3 "IPTOG toggled off globally"
	ip="#"
	iptog=0
fi

dbg2 "\n${CALLER}\n"

#sudo bash $FIJIONSERVER $CALLER