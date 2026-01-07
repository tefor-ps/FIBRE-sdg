//fsdb-rev-date: 251215

outSuff=getArgument();

dbgName="csGen";
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
title=getTitle();
tmp=split(title, ".");
bn=tmp[0];

// get metadata of image
getDimensions(width, height, channels, slices, frames);
getVoxelSize(vwidth, vheight, depth, vunit);
bd=bitDepth();

// make sure that all channels are visible
if (channels > 1){
	Property.set("CompositeProjection", "Sum");
	Stack.setDisplayMode("composite");
}

// extract center slice 
getDimensions(width, height, channels, slices, frames);
if ( channels > 1){
	cs=floor(slices/2);
	Stack.setSlice(cs);
	run("Duplicate...", "title=CS duplicate slices="+cs);
} else {
	run("Duplicate...", "duplicate");
}
// append application-specific suffix
if(indexOf(title, outSuff) == -1) {
	newName=title+outSuff;
	debugger(newName, LOG);
	rename(newName);
}
