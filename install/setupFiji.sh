#!/bin/bash
<<README
This script installs the correct (OS-specific) version of Fiji.
If the path of this script contains a fsdb-root-directory 
(e.g. a directory following the regex naming convention '/fsdb[0-9]{2}/')
Fiji is installed into that directory; else Fiji is installed into '$thisDir/../..'.

If this script encounters the "Windows subsystem for Linux (WSL)" it installes the Linux version of Fiji.

This script is integrating fiji into PATH by creating a link between the 
caller of the Fiji installation (Fiji/fiji) and /usr/local/bin/(fiji). 
If you don't want this, comment out the coresponding two lines a the end of this script.
The fsdb works without fiji being in PATH.

README

#fsdb-rev-date: 251028; tested, OK

## ======
## FUNCTION DEFINITIONS
## ======

function fail(){
	#intro "$@"
	date
	printf "\033[31mError in $(basename $0):${FUNCNAME[2]}:${FUNCNAME[1]} $@ \033[0m"
	printf "\033[31m\nExiting.\033[0m\n"
	exit 128
}

function sudoer() {
## ROOT PRIVILEDGES
# Because for the installation of software and generation of directories 
# on shares with limited write permissions root rights are needed, check for 
# these at the very beginning. 
	if [ "$(whoami)" != "root" ]; then 
		printf $'\r\e[2K\t\e[31;1;40m'"WARNING: This script needs to be run with root-priviledges."$'\e[0m\n' 
		exit
	fi
}

function error() { 
	if [[ -t 2 ]] ; then 
		date >> $LOG; 
		printf $'\e[37;1;41m'"\r\e[2KERROR:\t$0: $@"$'\e[0m\n' |tee -a $LOG
	else 
		echo "$@"
	fi >&2
}

## ======
## FUNCTION CALLS
## ======

# make sure, that the sourcing script is run as superuser/root
sudoer

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

echo "Installing to $FIJIDIR"

if [[ -f $FIJIDIR/fiji ]]; then
	fail "Fiji already exists at $FIJIDIR."
fi

# create temporary directory for download and unpacking.
TMPDIR=$ADMINDIR/tmp-$(basename $0 .sh)
mkdir -pv "$TMPDIR"
cd "$TMPDIR" || exit

printf "\n ... installing FIJI for "
# download OS-specific Fiji-version
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	# Linux
	if [[ $(uname -r |grep -c "[mM]icrosoft") -gt 0 ]]; then
		echo "WSL"
	else
		echo "Linux"
	fi
	FIJI=fiji-latest-linux64-jdk.zip
	MD5=${FIJI}.md5
elif [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OSX
	echo "MacOSX"
	FIJI=fiji-latest-macos64-jdk.zip
	MD5=${FIJI}.md5
elif [[ "$OSTYPE" == "cygwin" ]]; then
	# POSIX compatibility layer and Linux environment emulation for Windows
	echo "cygwin"
	FIJI=fiji-latest-win64-jdk.zip
	MD5=${FIJI}.md5
elif [[ "$OSTYPE" == "msys" ]]; then
	# Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
	echo "Windows; e.g., Git Bash, msysGit, Mingw32"
	FIJI=fiji-latest-win64-jdk.zip
	MD5=${FIJI}.md5
elif [[ "$OSTYPE" == "freebsd"* ]]; then
	# FreeBSD
	echo "FreeBSD"
	FIJI=fiji-latest-linux64-jdk.zip
	MD5=${FIJI}.md5
else
	# Unknown.
	printf "\r\t\tUnknown OS. Exiting."
	uname -a
	exit
fi

wget https://downloads.imagej.net/fiji/latest/$FIJI
wget https://downloads.imagej.net/fiji/latest/$MD5

if [[ "$(md5sum $FIJI |awk '{print $1}')" != "$(cat $MD5)" ]]; then
	echo "ERROR: md5 checksum mismatch. Exiting."
	exit 1
fi

## unpack Fiji, move it to the correct location, and remove the temporary directory
mkdir -pv "$FIJIDIR"
unzip fiji*zip
rsync -Sau Fiji/ "$FIJIDIR"

# update fiji
cd "$FIJIDIR" || exit
printf "\n ... updating Fiji\n"
bash fiji --update update

# link fiji into PATH
sed -i 's@dir=$(dirname "$0")@dir=$(dirname $(realpath "$0"))@' "$FIJIDIR"/fiji
ln -svf "$FIJIDIR"/fiji /usr/local/bin/fiji 

# change ownership
chown -R ${SUDO_USER}:${SUDO_USER} $FIJIDIR
chmod -R 775 $FIJIDIR

# clean up
rm -rf "$TMPDIR"

# user feedback
echo "Done."
