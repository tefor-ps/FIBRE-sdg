#!/bin/bash
<<README
This script is a wrapper to run fiji headlessly.
It accepts multiple images and macros, which must be directly followed by their 
macro-specific parameters (multiple parameters accepted).

For running on (storage-)servers (headless) this script is using the 
helper-wrapper xvfb-run-safe.sh, which prevents screen-clashes when running 
multiple instances in parallel.
xvfb-run-safe.sh searches for a non-used screen before starting fiji.
xvfb-run-safe.sh must be located in the same folder as this script.

Other computers run fiji interactively as $ADMIN .

README
#fsdb-rev-date: 260119

forceXvfb=0 # if this is greater than zero, it forces the execution in xvfb (on real Linux only) 
force=1

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

## ======
## FUNCTION DEFINITIONS
## ======

function installLatestJava(){
	latestJDK="$( apt-cache search openjdk |grep -e "-jdk" |grep "(JDK)" |grep -v headless |sort |head -1 |cut -d " " -f 1)"
	apt-get install -y "$latestJDK"
}

function complain(){
# output not-treated files to log and dedicated file
	dbg "$maxsize"
	dbg "$fileSize"
	dbg "$minsize"
	if [[ "$fileSize" -gt "$maxsize" ]]; then
		error "$rawImage is too big" |tee -a "$LOG"
		echo "$rawImage" |tee -a "$LOGDIR/$D.tooBig.txt"
	elif [[ "$fileSize" -lt "$minsize" ]]; then
		error "$rawImage is too small" |tee -a "$LOG"
		echo "$rawImage" |tee -a "$LOGDIR/$D.tooSmall.txt"
	fi
	exit
}

function fijiOnX11(){
# TODO: needs testing and potentially setup/modification of XAuth
	dbg "X11" |tee -a "$LOG"
	cd "$FIJIDIR" || exit
	echo "timeout ${TIMEOUTMINUTES}m fiji $IMG -macro $MACRO $PARAM 2>>\"$LOG\""
	timeout ${TIMEOUTMINUTES}m fiji $IMG -macro $MACRO $PARAM 2>>"$LOG"
}

function fijiOnXvfb(){
	dbg "xvbf" |tee -a "$LOG"
#check if helper script exists
	if [[ ! -f "$XVFB" ]]; then
		error " Can't find $XVFB"
	fi
	echo "timeout time: ${TIMEOUTMINUTES}m" >>$LOG
# run macro in virtual environment (not headlessly) for as long as $TIMEOUTMINUTES minutes.
# after $TIMEOUTMINUTES minutes, kill process because we have to assume, that it is stuck.
	echo "timeout ${TIMEOUTMINUTES}m \"$XVFB\" \"fiji $IMG -macro $MACRO $PARAM\"" 2>>"$LOG"
	timeout ${TIMEOUTMINUTES}m "$XVFB" "fiji $IMG -macro $MACRO $PARAM" 2>>"$LOG"
}

function fijiOnWayland(){
	dbg "Wayland - weston" |tee -a "$LOG"
	which weston
	if [[ $? -gt 0 ]]; then
		dbg2 "installing missing weston" |tee -a "$LOG"
		sudo apt update
		sudo apt install -y weston xwayland
	fi
	if [[ ! -f "$WESTON" ]]; then
		error " Can't find $WESTON"
	fi
	echo "timeout time: ${TIMEOUTMINUTES}m" >>$LOG
# run macro in virtual environment (not headlessly) for as long as $TIMEOUTMINUTES minutes.
# after $TIMEOUTMINUTES minutes, kill process because we have to assume, that it is stuck.
	echo "timeout ${TIMEOUTMINUTES}m \"$WESTON\" \"fiji $IMG -macro $MACRO $PARAM\"" 2>>"$LOG"
	timeout ${TIMEOUTMINUTES}m "$WESTON" "fiji $IMG -macro $MACRO $PARAM" 2>>"$LOG"
}

function fijiOnWindows() {
	dbg "Windows" |tee -a "$LOG"
	#for e.g., MobaXterm; doesn't really start-up
# TODO: make this work, untested
	cd "$FIJIDIR" ||exit
	FIJI="$FIJIDIR/ImageJ-win64.exe"
# run macro on image in normal fiji
	#"$FIJI" -macro "$MACRO" "$PARAM" "$IMG" 2>>"$LOG"
	"$FIJI" "$IMG" -macro "$MACRO" "$PARAM"  2>>"$LOG"
}

function fail(){
	#intro "$@"
	date
	printf "\033[31mError in $(basename $0)::${FUNCNAME[2]}:${FUNCNAME[1]} $@ \033[0m"
	printf "\033[31m\nExiting.\033[0m\n"
	exit 128
}

function get_active_session_type() {
#DEPRECATED	
    local user=${SUDO_USER:-$USER}
    local best_sid=""
    local best_ts=0
    local best_type=""

    while read -r sid _; do
        # Read all needed properties in one call
        local Name Active Remote Seat Type Timestamp
        readarray -t props < <(
            loginctl show-session "$sid" \
                -p Name -p Active -p Remote -p Seat -p Type -p Timestamp \
                --value 2>/dev/null
        )

        # Skip if session disappeared
        [ "${#props[@]}" -lt 6 ] && continue

        Name=${props[0]}
        Active=${props[1]}
        Remote=${props[2]}
        Seat=${props[3]}
        Type=${props[4]}
        Timestamp=${props[5]}

        # Normalize timestamp → epoch (fallback safe)
        local ts_epoch
        ts_epoch=$(date -d "$Timestamp" +%s 2>/dev/null || echo 0)

        # Apply filters
        if [ "$Name" = "$user" ] &&
           { [ "$Active" = "yes" ] || [ "$Active" = "online" ]; } &&
           [ "$Remote" = "no" ] &&
           [ "$Seat" = "seat0" ]; then

            # Prefer Wayland immediately
            if [ "$Type" = "wayland" ]; then
                echo "wayland"
                return 0
            fi

            # Otherwise keep best fallback (typically X11)
            if [ -z "$best_sid" ] || [ "$ts_epoch" -ge "$best_ts" ]; then
                best_sid=$sid
                best_ts=$ts_epoch
                best_type=$Type
            fi
        fi
    done < <(loginctl list-sessions --no-legend)

    # Fallback to best candidate
    if [ -n "$best_sid" ]; then
        echo "$best_type"
        return 0
    fi

    # Final fallback: environment (containers / non-systemd)
    if [ "$XDG_SESSION_TYPE" = "wayland" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        echo "wayland"
    elif [ "$XDG_SESSION_TYPE" = "x11" ] || [ -n "$DISPLAY" ]; then
        echo "x11"
    else
        echo "none"
        return 1
    fi
}

get_headless_display() {
    if command -v weston &>/dev/null; then
        echo "wayland"
    elif command -v Xvfb &>/dev/null; then
        echo "X11"
    else
        echo "none"
    fi
}

function defineFiji(){
	dbg2 "$(date)" |tee -a "$LOG"
# define fiji to work with 
	if [[ "$(uname)" == "Linux" ]]; then
		if [[ $(grep -ic microsoft /proc/version) -gt 0 ]]; then
			dbg "WSL" |tee -a "$LOG"
			fijiOnX11
		else
			dbg "Linux" |tee -a "$LOG"
			if [[ $force -eq 0 ]]; then
				fijiOnX11
			else
				gs=$(get_headless_display)
				dbg2 "gs: $gs"
				if [[ "$gs" == "wayland" ]]; then
					fijiOnWayland
				elif [[ "$gs" == "X11" ]]; then
					fijiOnXvfb
				else
					echo "Unknown graphical session. Exiting."
					exit
				fi
			fi
		fi
	else
		dbg "Windows" |tee -a "$LOG"
		fijiOnWindows
	fi
	# clean-up leftovers of this run
	sudo rm -vf /tmp/ImageJ-*stub
	#
	if [[ $? -eq 124 ]]; then
		dbg "$0 TIMEOUT" >>"$LOG"
	else
		dbg "$0 DONE" >>"$LOG"
	fi
	dbg2 "$(date)\n"
}

## ======
## FUNCTION CALLS
## ======
# if no java is installed on the current machine, install the latest java runtime envorinment
#DEPRECATED?
which java >/dev/null
if [[ $? -eq 1 ]]; then
	installLatestJava
else
	jv=$(java --version |head -1 |cut -d " " -f 2 |cut -d "." -f 1)
	if [[ $jv -le 8 ]]; then
		installLatestJava
	fi
fi

dbg "LOG: $LOG"

dbg2 "call: $0 $@" |tee -a "$LOG"
# ensure, that all needed network drives are mounted

# make sure FIJIDIR and the scripts within are executable
sudo chmod -R 770 "$FIJIDIR"

# populate variables
inArr=(${@})
iArr=()
mArr=()
pArr=()
j=0

maxInd=$((${#inArr[@]}-1))
dbg2 "maxInd: $maxInd"
TESTER=/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.tester.ijm
if [[ ${inArr[0]} == $TESTER ]]; then
	dbg "tester detected" |tee -a "$LOG"
	IMG=""
	MACRO=$TESTER
	# define fiji to work with 
	defineFiji
elif [[ $maxInd -eq 0 && ${inArr[0]} == $CALLER ]]; then
	dbg "caller detected" |tee -a "$LOG"
	IMG=""
	MACRO=$CALLER
	# define fiji to work with 
	defineFiji
else
	for i in $(seq 0 $((${#inArr[@]}-1))); do	# analyze all provided parameters
		dbg "$i ${inArr[$i]}"
		if [[ -f "${inArr[$i]}" ]]; then		# work on parameters, which are files
			if [[ "${inArr[$i]}" =~ ".ijm" ]]; then # work on files, which are macros
				mArr[$j]="${inArr[$i]}"			# assign to macro-array (mArr)
				dbg2 "$j: ${mArr[$j]}"
				unset 'inArr[$i]'				# remove from input array (inArr)
			#	dbg2 ":: $((${#inArr[@]}-1))"
				if [[ $i -le $maxInd ]]; then
					ni=$((i+1))					# increase index (next index, ni) to search for the parameters of the current macro
					dbg2 "ni: $ni"
					#read ans
					if [[ -f ${inArr[$ni]}  ]]; then # if the next parameter is a file, there are no parameters to the current macro 
						echo "next file"
					else
						tArr=()					# initialise temporary array (tArr) empty
						while [[ ! -f ${inArr[$ni]} && $ni -le $maxInd ]]; do # assign all non-file parameters to tArr
							tArr+=("${inArr[$ni]}")
							dbg2 "$ni: ${tArr[@]}" 
							unset 'inArr[$ni]'	# ... and remove them from inArr
							ni=$((ni+1))
						done
						pArr[$j]="${tArr[@]}"	# assign macro parameters to parameter array (pArr) at the current index (j)
					fi
				fi
				j=$((j+1))
			else
				iArr+=("${inArr[$i]}")			# if a detected file is not a macro, it must be an image; assign to image array (iArr)
				unset 'inArr[$i]'				# ... and remove from inArr.
			fi
		fi
	done
	
	dbg3 "IN: ${inArr[@]}" |tee -a "$LOG"
	dbg3 "I: ${iArr[@]}" |tee -a "$LOG"
	dbg3 "M: ${mArr[@]}" |tee -a "$LOG"
	dbg3 "P: ${pArr[@]}" |tee -a "$LOG"
	
	if [[ ${#inArr[@]} -eq 0 ]]; then	# If all elements of the list of inputs were recognized,...
		
		
		
		for IMG in ${iArr[@]}; do		# ... process each provided image ...
			for i in ${!mArr[@]}; do	# ... with each provided macro (respecing their parameters)
				echo
				#echo $i
				MACRO=${mArr[$i]}
				PARAM=$(echo ${pArr[$i]} |sed 's@ @,@g')
				echo "macro: $MACRO" |tee -a "$LOG"
				echo "param: $PARAM" |tee -a "$LOG"
				echo "image: $IMG" |tee -a "$LOG"
	
				whoami >> "$LOG"
				
				# check file size and make the decision to run on the current hardware or to skip the processing of this image
				if [[ -f "$IMG" ]]; then
					fileSize=$(ls -l "$IMG" |cut -d " " -f 5)
				else
					fileSize="$minsize"
				fi 
				echo "filesize: $fileSize" |tee -a "$LOG"
				
				if [[ "$fileSize" -gt "$maxsize"  ]]; then
					complain	# exit, if file size is too big
				fi
				if [[ $force -eq 0 ]]; then
					if [[  "$fileSize" -lt "$minsize" ]]; then
						complain	# exit, if file size is too small
					fi
				fi
				# define fiji to work with 
				defineFiji
			done
		done
	else
		echo "ERROR: unclear elements in call: ${inArr[@]}. EXITING." |tee -a "$LOG"
		exit
	fi
fi

date >>"$LOG"

exit 0
