//fsdb-rev-date: 260115

if (getArgument() == "") {
	title=getTitle();
	ft=replace(title, ".*\\.", "\\.");
	//print(suff);
	bn=replace(title, ft, "");
	//print(bn);
	dir=getDirectory("image");
	outPath=dir+"/"+bn+"-secData/"+bn+".png";
} else {
	outPath=getArgument();
}

dbgName="savePng";
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

COREMACROS=FSDBDIR+"/fsdb-core/macros/fsdb.core/";
INITLOG_FMAC=COREMACROS+"/fsdb.core.initLOG.ijm";
DEBUG_FMAC=COREMACROS+"/fsdb.core.logger.ijm";
MAKEDIR_FMAC=COREMACROS+"/fsdb.core.makeDirRecursively.ijm";

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

runMacro(MAKEDIR_FMAC, outPath);

if (dbg > 0) { debugger("outPath: "+outPath, LOG); }

if (File.exists(outPath) == 0) {
	getDimensions(width, height, channels, slices, frames);
	if (channels > 1) {
		run("Make Composite");
		Stack.setDisplayMode("composite");
		run("RGB Color");
	} else {
		run("8-bit");
	}
	saveAs("PNG", outPath);
	close();
	debugger(outPath, LOG);
} else {
	debugger(outPath+" already exists", LOG);
}
debugger("end", LOG);