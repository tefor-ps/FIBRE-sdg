# fsdb - module - default

This repository contains the default structure of a module for the fsdb (file system based database)
----

## Installation of a (empty) default module

When starting to develop a new module for the fsdb we recommend to start with installing this. 

## .scripts.config
```bash
### ==ACCOUNTS==
ADMIN yourAdmin			# <-- sudo-enabled UNIX account
CONSORTIUM yourAssociation		# <-- normal UNIX account
GROUP yourTeam			# <-- UNIX group, which groups the users of a lab
DEV yourDevTeam			# <-- developer accounts have access to the scripts without being ADMIN
DEVACCOUNTS devacc1 devacc2 devacc3	# <-- developers of the fsdb
ADMINACCOUNTS adminacc1 adminacc2 adminacc3	# <-- other system administrators, sudo-enabled 
USERACCOUNTS useracc1 useracc2 useracc3	# <-- list of linux user accounts 
### ==DIRECTORIES==
LAB yourTeamName			# <-- name of the local lab for the file system structure
USER user1 user2 user3		# <-- names of users, space delimited, defining their storage locations on microscopes
### == VARIABLES==
# D and STARTDATE are set dynamically within getVar
DEBUGLEVEL 1			# <-- default debug verbosity level (0: silent, 1:some output, 2:verbose)
HOSTS 127.0.0.1		# <-- allowed hosts for smb.conf, comma-separated

#### MODIFICATIONS BELOW THIS POINT ARE POSSIBLE BUT NOT RECOMMENDED ####
### ==ACCOUNTS==
GROUPACCOUNTS \$ADMIN \$GROUP \$CONSORTIUM \$DEV
### ==DIRECTORIES==
FSDBVERSION fsdb23			# <-- version number of the fsdb
DATAROOT /DATA				# <-- root of the fsdb
BUPROOT /BUP				# <-- root of the hot backup archive
LABDIR \$DATAROOT/\${LAB}		# <-- all data of a given lab goes into a structured tree, which is rooted here
EXPORTDIR \$DATAROOT/export/\${LAB}	# <-- folder accessible to all labs of the same consortium - within the same network.
STORAGEDIR \$LABDIR/storage	# <-- hidden/protected storage location for raw data
LABDATADIR \$LABDIR/labdata	# <-- lab-accessible location for all data (raw, secondary, tertiary, annotation, ...)
ATTICDIR \$LABDIR/sysadmin	# <-- hidden storage location for the systems administrator
DUMPDIR \$LABDIR/dump		# <-- intermediate storage location for the clean-up processes
IMPORTS imports				# <-- subfolder in both storage locations; facilitates introduction of other data modalities
ARCHIVEDIR \$LABDATADIR/archive	# <-- output folder for table of content of compressed archives 
EXCHANGEDIR \$LABDATADIR/exchange	# <-- central storage location for lab-interal file-exchange, read-writable for lab members
PROJECTSDIR \$LABDATADIR/projects	# <-- same data as in \$LABDATA; but sorted by projectID
LOGDIR \$WORKDIR/logs		# <-- storage location for the fsdb log files
INDEXDIR \$WORKDIR/index		# <-- storage location for the fsdb index files
MATDIR \$WORKDIR/install		# <-- location for installation components
TEMPLATESDIR \$MATDIR/templates	# <-- location for configuration file templates

### ==MAIN CONFIGURATION==
# DO NOT EDIT THE MAIN CONFIGURATION FILE AS IT WILL BE COMPLETELY OVERWRITTEN
# AS SOON AS A SUB-CONFIGURATION FILE IS MODIFIED
CONFIG \${SCRIPTSDIR}/.scripts.config

## ==extenal softwares==
FIJIDIR \$SCRIPTSDIR/Fiji.app	# <-- location of the integrated instance of fiji
ONLINEDOC https://gitlab.com/arnimjenett/fsdb23#installation-of-the-fsdb

### ==FILES==
LOGO \$SCRIPTSDIR/logo.png	# <-- storage location of the lab's logo for integration into the movies

### ==CENTRALLY DEFINED PARAMETERS==
permissibleAgeOfIndex 360	# <-- used in makeIndex to prevent rewriting a recently written index
TIMEOUTMINUTES 30		# <-- time in minutes allowed for all secData-generation processes (per raw dataset).

# ==> Modify values below in /mnt/c/Users/teforadmin/tps/sandbox/fsdb-dev-test/fsdb-minimal/scripts/core/core.config <==
# ==fsdb core functions==
CORENAME core
COREDIR $SCRIPTSDIR/core
COREMACROS $MACROSDIR/fsdb.core

# ==CORE SCRIPTS==
MAKEINDEX $COREDIR/makeIndex.sh
MAKEFSDBINIT $COREDIR/makeFsdbInit.sh	# <-- translates the label/value-pairs of scripts.config into ij.Prefs for use in fiji
FIJIONSERVER $COREDIR/fijiOnServer.sh
COMPLISTS $COREDIR/compareLists.sh		# <-- compares the fist column of two lists (files)
UPDATEFSDB $COREDIR/updateFsdb.sh		# <-- updates the fsdb from online repo
UPDATEMACROS $COREDIR/updateMacros.sh		# <-- updates fsdb-macros from import location to active location (FIJIDIR)
POPVARS_SCR $COREDIR/populateVarsInMacro.sh 	# <-- populates/updates fsdb-variables within macros
POPVARS_FUN $COREDIR/getFsdbVars_fun.txt      # <-- transplantable function used by POPVARS_SCR
CHECKPATH $COREDIR/checkFilePath.sh		# <-- eliminates incompatible filenames
REMOVERAWDATA $COREDIR/removeRawDataFromFsdb.sh

# functional (helper) core macros
INITLOG_FMAC $COREMACROS/fsdb.core.initLOG.ijm
DEBUG_FMAC $COREMACROS/fsdb.core.logger.ijm
MAKEDIR_FMAC $COREMACROS/fsdb.core.makeDirRecursively.ijm
TIMESTAMP_FMAC $COREMACROS/fsdb.core.ts.ijm
DISSECTNAME_FMAC $COREMACROS/fsdb.core.dissectFilename.ijm
SAVESTACK_FMAC $COREMACROS/fsdb.core.saveStack.ijm 
SAVEPNG_FMAC $SECDATAMACROS/fsdb.sdg.savePng.ijm 
# the following initially does not exist but is dynamically created by MAKEFSDBINIT
INITFSDB_FMAC $COREMACROS/fsdb.core.initFsdb.ijm

### == VARIABLES==
LEICA_FT lif
ZEISS_FT czi
NIKON_FT nd2
STACKEXTENSION nd2 lif		# <-- expandible list of treated file extension (currently possible values: nd2 czi lif)
STACKMODALITY stack tiles merge multi	# <-- expandible list of stack-modality defining filename components (last element of basename!)


# ==> Modify values below in /mnt/c/Users/teforadmin/tps/sandbox/fsdb-dev-test/fsdb-minimal/scripts/janitor/janitor.config <==
# ==fsdb maintenance==
MAINTENANCEDIR $SCRIPTSDIR/janitor

### == TOGGLES FOR FILE-SYSTEM RELATED FUNCTIONS==
PROJECT_FSTOG 1				# <-- populates the PROJECTSDIR
JANITOR_FSTOG 1				# <-- cleans up and ensures, that all conncetions/links are established

# ==housekeeping==
JANITOR $MAINTENANCEDIR/janitor.sh
CLEANIMPORTS $MAINTENANCEDIR/cleanImports.sh
CLEANTMP $MAINTENANCEDIR/cleanTmp.sh
CLEANEXCHANGE $MAINTENANCEDIR/cleanExchange.sh
CLEANDUMP $MAINTENANCEDIR/cleanDump.sh
CLEANLOCKS $MAINTENANCEDIR/cleanLocks.sh
CLEANLIFEXT $MAINTENANCEDIR/removeLifext.sh
FIXLINKS $MAINTENANCEDIR/fixLinks.sh
FIXPERMISSIONS $MAINTENANCEDIR/fixPermissions.sh
MAKEPROJECTDIRS $MAINTENANCEDIR/makeProjectLinks.sh

```
------
## file-specific documentation for the fsdb    
(in alphabetical order)
---

