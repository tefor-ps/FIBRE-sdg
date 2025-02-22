#!/bin/bash
<<README
This script is something like a minimal version of a fsdb-module, which can be used 
as starting point for the development of more complex fsdb-modules.
The variable fsdbDir needs to be defined as path to your fsdb-instance. 
This can be the minimal version from https://gitlab.com/tefor/fsdb-minimal .

- setup
For de-novo development we suggest to install (at least) the minimal fsdb and 
your module into a common root directory. E.g.,
	mkdir dev-dir
	cd dev-dir
	git clone https://gitlab.com/tefor/fsdb-minimal.git
	git clone https://gitlab.com/tefor/fsdb-module-defaultHeader
	mv fsdb-module-defaultHeader yourNewModule
	cd yourNewModule
	mv module.defaultHeader.sh yourNewModule.sh
	vim yourNewModule.sh #<-- configure fsdbDir as needed (see below)
	mv module.config.default yourNewModule.config
	rm -rf .git
	git init
subsequently you should test-run yourNewModule
	sudo bash yourNewModule.sh
which should yield
	TESTVAR: giraffe
	TESTDIR: [the directory you are runnning yourNewModule from]

As the fsdb-minimal needs an OS-specific installation of FIJI you should subsequently
install the correct FIJI version from https://imagej.net/software/fiji/downloads into 
fsdb-minimal/scripts/Fiji.app and update it.
	
ALTERNATIVELY you can run the provided install/setup.sh, which is guiding you through
the steps above, incl. the installation and update of the OS-specific version of FIJI
via setupFiji.sh of fsdb-minimal.
	
- config-file
TESTVAR and TESTDIR are defined in module.config.default which you renamed to yourNewModule.config.
yourNewModule.config is the template for the configuration file of yourNewModule.
By default it is a flat text file with a pair of variable-name and variable-value per line. 
Comments are started with hash-tag (#). They can be in-line with a name-value pair.

- fsdbDir
The variable fsdbDir enables this script to find getVar.sh, which populates/exports 
all variables defined in the config-files of the fsdb.
It is supposed to point to the (minimal) installation of the fsdb. 
E.g., if you followed the steps above and this script is located in a directory 
next to an fsdb-installation, the default value (fsdbDir=../../../fsdb-minimal) does not need 
to be changed.
	commonDir
	|-fsdb-minimal
	|-yourNewModule
	|  |-yourNewModule.sh
	|  |-yourNewModule.config
	|  |-...
	|-...
Otherwise you will have to inform yourNewModule, where it can find your 
fsdb-installation by redefining fsdbDir.

- debug
The variable debug defines the verbosity of the debugging messages.
If commented the DEBUGLEVEL (defined in fsdb.config) is govering the debugging.
Valid levels are 0-3 with increasing verbosity.

- formatted/colored messages
intro, dgb, and dbg2 are formatted printf commands defined in fun_colMsg.sh and sourced by getVar.sh.

- git
local config files (*.config) are explicitly ignored by git (.gitignore).

README

thisDir="$(dirname "$(realpath "$0")")"                   # gets the directory of this script. thisDir is used by getVar.sh to find the local config-file. 
fsdbDir="$(realpath "$thisDir/../../../fsdb-minimal")"    # defines directory of core-functions of the fsdb    

#============================
# define variables of the fsdb
#============================
# set all global variables
GV=$(find "$fsdbDir" -name getVar.sh) # getVar.sh builds the central config-file of the fsdb and populates/exports the name-value pairs within to all scripts which are sourcing it. 
realpath "$GV"                # just an echo to facilitate the retrieval and study of getVar.sh
if [[ -f "${GV}" ]]; then
	source "${GV}"                    # integrate everything in getVar.sh here, run it.
else
	FIJIONSERVER="$fsdbDir/scripts/core/fijiOnServer.sh"


fi

debug=2

intro $0	                            # when scripts call scripts this 'sign of life' shows, which one is currently running.  

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