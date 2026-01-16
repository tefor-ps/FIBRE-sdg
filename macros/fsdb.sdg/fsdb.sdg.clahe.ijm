//fsdb-rev-date: 260109

if (getArgument() == "") {
	outSuff=".cl";
} else {
	outSuff=getArgument();
}
title=getTitle();
if(indexOf(title, ".") == -1) {
	ft="";
	bn=title;
} else {
	ft=replace(title, ".*\\.", "\\.");
	//print(suff);
	bn=replace(title, ft, "");
	//print(bn);
}

dbgName="clahe";
dbg=1; // debugging; active, when greater than 0
interactive=0;
ic=0;
if (dbg > 0) { print("::"+dbgName); }
fs=File.separator;

//myPath=getInfo("macro.filepath");
myPath=getDirectory("current");
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
DESPtog=0;

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

// get ImageID
IID=getImageID();
selectImage(IID);

if (interactive > 1 ){
	waitForUser(dbgName+" title: "+title);
}	
debugger(title, LOG);

//remove background speckles before CLAHE
if(DESPtog == 1){
	if (slices > 1){
		run("Despeckle", "stack");
	} else {
		run("Despeckle");
	}
	outSuff="d"+outSuff;
}

ThreeDclahe();

//remove background speckles after CLAHE
if(DESPtog == 2){
	if (slices > 1){
		run("Despeckle", "stack");
	} else {
		run("Despeckle");
	}
	outSuff=outSuff+"d";
}
// append application-specific suffix
if(indexOf(title, outSuff) == -1) {
	newName=bn+outSuff;
	debugger(newName, LOG);
	rename(newName);
}

debugger("end", LOG);

function ThreeDclahe(){
	File.append(dbgName+": start", LOG);
	
	getDimensions(width, height, channels, slices, frames);
	run("Duplicate...", "title=CLAHE duplicate");
// accelerate procession by batchMode	
	setBatchMode(1);
// turn RGB images into three-channel-images	
	if (bitDepth() == 24) {
		run("Make Composite");
	}
// run CLAHE on each channel of each slice	
	for (slice=1; slice<=slices; slice++){
		Stack.setSlice(slice);
		for (channel=1; channel <= channels; channel++){
			Stack.setChannel(channel);
			resetMinAndMax;
		}
		run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None* fast_(less_accurate) process_as_composite");
	}
	setBatchMode(0);
}