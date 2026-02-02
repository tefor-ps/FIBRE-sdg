//fsdb-rev-date: 260115

if (getArgument() == "") {
	title=getTitle();
	ft=replace(title, ".*\\.", "\\.");
	//print(suff);
	bn=replace(title, ft, "");
	//print(bn);
	dir=getDirectory("image");
	outPath=dir+"/"+bn+"-secData/"+bn+".nrrd";
} else {
	outPath=getArgument();
}

dbgName="saveNrrd";
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

IID=getImageID();
title=getTitle();
debugger("title: "+title, LOG);
// detect number of channels
getDimensions(width, height, channels, slices, frames);
debugger("channels: "+channels, LOG);

// as the following process is destructive make a duplicate of the original data 
run("Duplicate...", "title=DUP duplicate");
DID=getImageID();
print("DID:", DID);
if (channels > 1) {
// split outPath as preparation for the inserion of the channel number
	bp=replace(outPath, "\\..*", "");
	suff=replace(outPath, bp, "");
	print("bp:", bp,"\nsuff:", suff);
// split duplicate into single channel images	
	run("Split Channels");
	//run("Tile");
	wait(100);
// save each channel as separate nrrd
	for (i = 1; i <= channels; i++) {
		selectImage(DID-i);
		wait(1000);
		selectImage(DID-i);
		print(getImageID(), ":", getTitle());
		ch=replace(getTitle(), "-DUP", "");
		debugger("channel "+ch, LOG);
		chOut=bp+"-"+ch+suff;
		//chOut=ch+"-"+title;
		debugger("chOut:"+chOut, LOG);
		run("Nrrd ... ", "nrrd="+chOut);
		close();
	}
} else {
	run("Nrrd ... ", "nrrd="+outPath);
	close();
}
debugger(outPath, LOG);
// free memory
run("Collect Garbage");
run("Collect Garbage");
run("Collect Garbage");

// go back to original image
selectImage(IID);

// confirm finished status
debugger("end", LOG);