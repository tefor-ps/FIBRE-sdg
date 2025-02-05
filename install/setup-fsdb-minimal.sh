#!/bin/bash
<<README
This script sets up the minimal version of the fsdb.

README

# define the location of your development environment/location
if [[ -z $1 ]]; then
	DEVDIR=$(pwd)/dev-dir
else
	DEVDIR=$1
fi
# create development location and move into it 
mkdir -pv $DEVDIR
cd $DEVDIR

# clone the minimal version of the fsdb into your development location
printf "\n... getting https://gitlab.com/tefor/fsdb-minimal.git\n"
git clone https://gitlab.com/tefor/fsdb-minimal.git
if [[ $? -gt 0 ]] ;then
	printf "WARNING: Cloning failed, try again."
	git clone https://gitlab.com/tefor/fsdb-minimal.git
fi	
# activate default configs within fsdb-minimal
for defaultConfig in $(find $DEVDIR/fsdb-minimal/ -name "*config.default"); do
	config=$(echo $defaultConfig |sed 's@.default@@')
	cp -v $defaultConfig $config
done

# as Fiji is OS-specific it is installed directly from https://imagej.net/
FIJIINSTALLER=$(find $DEVDIR -name setupFiji.sh)
echo $FIJIINSTALLER
sudo bash $FIJIINSTALLER $(pwd)

