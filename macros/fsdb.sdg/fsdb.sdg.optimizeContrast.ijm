//fsdb-rev-date: 251215

outSuff=getArgument();

dbgName="optimizeContrast";
dbg=1; // debugging; active, when greater than 0
interactive=0;
ic=0;
if (dbg > 0) { print("::"+dbgName); }
fs=File.separator;

myPath=getInfo("macro.filepath");
print(myPath);
pArr=split(myPath, "/");
for (i = 0; i < lengthOf(pArr); i++) {
	if (matches(pArr[i], "fsdb..") == 1) {
		FSDBVERSION=pArr[i];
		FSDBDIR=replace(myPath, FSDBVERSION+"/.*", FSDBVERSION);
	} else {
		FSDBDIR=myPath+"/../../../";
	}
}
FSDBDIR=replace(myPath, FSDBVERSION+"/.*", FSDBVERSION);
print(FSDBDIR);

if (dbg > 0) { print(dbgName+": A"); }
COREMACROS=FSDBDIR+"/fsdb-core/macros/fsdb.core/";
INITLOG_FMAC=COREMACROS+"/fsdb.core.initLOG.ijm";
DEBUG_FMAC=COREMACROS+"/fsdb.core.logger.ijm";

// prepare parameters for logging
LOG=runMacro(INITLOG_FMAC, dbgName);

function debugger(str, LOG){
	if (dbg > 0){
		str=dbgName+dbg+": "+str+" "+LOG;
		runMacro(DEBUG_FMAC, str);
		dbg++;
	}
}

debugger("start", LOG);
if (interactive > 0 ) {waitForUser(dbgName+" "+ic); ic++;}
//==== fsdb-end ====

// get name and basename of active image
IID=getImageID();
title=getTitle();
tmp=split(title, ".");
bn=tmp[0];

getDimensions(width, height, channels, slices, frames);
// ensure, all channels are visible
if(channels > 1 || bitDepth() == 24 ){
	if (is("composite") == 0) {
		run("Make Composite");
	}
}
// enhance contrast for each channel (10% of oversaturated voxels permitted)
run("Z Project...", "projection=[Max Intensity]");
MID=getImageID();
for (i = 1; i <= channels; i++) {
	selectImage(MID);
	Stack.setChannel(i);
	resetMinAndMax;
	run("Enhance Contrast", "saturated=0.1");
	getMinAndMax(min, max);
	selectImage(IID);
	Stack.setChannel(i);
	setMinAndMax(min, max);
}
selectImage(MID);
close();
// append application-specific suffix
if(indexOf(title, outSuff) == -1) {
	newName=title+outSuff;
	debugger(newName, LOG);
	rename(newName);
}

debugger("end", LOG);
