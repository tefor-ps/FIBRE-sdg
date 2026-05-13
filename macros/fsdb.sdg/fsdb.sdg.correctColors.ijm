//fsdb-rev-date: 260512

if (getArgument() == "") {
	outSuff="-cc";
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

dbgName="correctColors";
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

// apply standard colors to all channels
correctColors();
// append application-specific suffix
if(indexOf(title, outSuff) == -1) {
	newName=bn+outSuff;
	debugger(newName, LOG);
	rename(newName);
}

debugger("end", LOG);

function correctColors() {
	getDimensions(width, height, channels, slices, frames);
	print(width, height, channels, slices, frames);
	
	if ( channels == 1 ){
		debugger("one channel --> grays", LOG);
		run("Grays");
	} else {
// make sure that all channels are visible
		Property.set("CompositeProjection", "Max");
		Stack.setDisplayMode("composite");
	}
	if ( channels == 2 ){
		debugger("two channels --> gagenta/green", LOG);
		luts=newArray("Magenta", "Green", "Grey");
		for (i=0;i<channels;i++){
			Stack.setChannel(i+1);
			run(luts[i]);
		}
	}
	if ( channels > 2 ){
		debugger("more than two channels --> RGBGMYC", LOG);		
//		luts=newArray("Magenta", "Yellow", "Cyan", "Red", "Green", "Blue", "Grays");
		luts=newArray("Red", "Green", "Blue", "Grays", "Magenta", "Yellow", "Cyan");
		for (i=0;i<channels;i++){
			Stack.setChannel(i+1);
			run(luts[i]);
		}
	}
}
