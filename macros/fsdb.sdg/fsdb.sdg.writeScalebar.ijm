//fsdb-rev-date: 260109

if (getArgument() == "") {
	outSuff=".sb";
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

dbgName="scalebar";
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

getDimensions(width, height, channels, slices, frames);
getVoxelSize(vwidth, vheight, vdepth, unit);
if ( width+vwidth > 400 ){
	w=100;
 } else if ( width+vwidth > 100 ) {
	w=10;
} else { 
	w=1;
}
//run("Scale Bar...", "width="+w+" height=4 font=14 color=White background=None location=[Lower Right] bold overlay");
run("Scale Bar...", "width="+w+" height=4 font=14 color=White background=None location=[Lower Right] bold overlay label");

// append application-specific suffix
if(indexOf(title, outSuff) == -1) {
	newName=bn+outSuff;
	debugger(newName, LOG);
	rename(newName);
}

debugger("end", LOG);