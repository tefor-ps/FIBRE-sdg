//fsdb-rev-date: 241211
/*
This macro expects one parameter:
- the original number of channels (origNumChannels)

*/
dbgName="deinterleaveStack";
dbg=0; // debugging; active, when greater than 0
interactive=0;
ic=0;
if (dbg > 0) { print("::"+dbgName); }
fs=File.separator;

test_tog=call("ij.Prefs.get", "fsdb.core.tog.test", 0);
test_tog=1;
call("ij.Prefs.set", "fsdb.core.tog.test", test_tog);
if (dbg > 0) {print(dbgName+" test_tog:", test_tog); }

FIJIDIR=getInfo("user.dir");
FIJIDIR=replace(FIJIDIR, fs, "/");

if (test_tog == 1) {
	if (dbg > 0) { print(dbgName+": A"); }
//	if (getInfo("os.name") == "Linux"){
//		FIJIDIR="/home/teforadmin/tps/gitlab/fsdb23/scripts/Fiji.app/";
//		//fn=replace(fn, "//wsl.localhost/Ubuntu-22.04", "");
//	} else {
//		FIJIDIR="C:/Users/teforadmin/tps/gitlab/fsdb23/scripts/Fiji.app/";
//	}	
// import necessary variables into fiji
	MACROSDIR=FIJIDIR+"/macros";
	COREMACROS=MACROSDIR+"/fsdb.core";
	SECDATAMACROS=MACROSDIR+"/fsdb.sdg";
	MERGECHANNELS_FMAC=SECDATAMACROS+"/fsdb.sdg.mergeChannels.ijm";
	INITLOG_FMAC=COREMACROS+"/fsdb.core.initLOG.ijm";
	DEBUG_FMAC=COREMACROS+"/fsdb.core.logger.ijm";
} else {
	if (dbg > 0) { print("B"); }
// get all varables defined in the .scripts.config of the fsdb
//	if (getInfo("os.name") == "Linux"){
//		FIJIDIR=getDirectory("imagej");
//	} else {
//		FIJIDIR=File.getDirectory(getInfo("ij.executable"));
//	}
	// import fsdb-variables into fiji
//	INITFSDB_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initfsdb", COREMACROS+"/fsdb.core.initFsdb.ijm"); 
	INITFSDB_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initfsdb", FIJIDIR+"/macros/fsdb.core/fsdb.core.initFsdb.ijm"); 
	runMacro(INITFSDB_FMAC);
	MACROSDIR=call("ij.Prefs.get", "fsdb.getVar.static.macrosdir", FIJIDIR+"/macros");
	COREMACROS=call("ij.Prefs.get", "fsdb.core.dir.coremacros", MACROSDIR+"/fsdb.core");
	SECDATAMACROS=call("ij.Prefs.get", "fsdb.core.dir.secdatamacros", MACROSDIR+"/fsdb.sdg");
	MERGECHANNELS_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.deinterleave",SECDATAMACROS+"/fsdb.sdg.mergeChannels.ijm");	
	INITLOG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initlog", COREMACROS+"/fsdb.core.initLOG.ijm");
	DEBUG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.debug", COREMACROS+"/fsdb.core.logger.ijm");
}

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
origNumChannels=getArgument();
//origNumChannels=2;

getDimensions(width, height, channels, slices, frames);
print(width, height, channels, slices, frames);

IID=call("ij.Prefs.get", "fsdb.ants-reg.stack.id", getImageID());
debugger("inID: "+IID, LOG);
deinterleaveStack(origNumChannels);
IID=getImageID();
debugger("outID: "+IID, LOG);
call("ij.Prefs.set", "fsdb.ants-reg.stack.id", IID);
return toString(IID);

function deinterleaveStack(origNumChannels){
	debugger("deinterleaveStack", LOG);
	call("java.lang.System.gc");
	call("java.lang.System.gc");
// for unknown reasons fiji (sometimes) turns multi-channel-images into interleaved images during reslicing.
// this function evaluates the number of slices before and after this process and fixes this error.
// this is a bad hack, but the best I can come up with at this moment.

// get current dimensions of stack to compare with passed parameters
	getDimensions(width, height, channels, slices, frames);
	//if(slices > origNumOfSlices) {
	if (channels < origNumChannels) {
// get basename for re-application after this procedure		
		title=getTitle();
		bn=split(title, ".");
		bn=bn[0];
// rename stack during the procedure		
		tmpTitle="TMP";
		rename(tmpTitle);
		debugger("deinterleaving", LOG);
// deinterleave stack		
		run("Deinterleave", "how="+origNumChannels);
// adjust image names to fit following processes (turn e.g '#1' at the end into 'C1-' at the front.
// get list of open images
		list = getList("image.titles");
		Array.print(list);
// create temporary arrays to store the imageIDs and channel numbers in		
		iArr=newArray(origNumChannels);
		cArr=newArray(origNumChannels);
		for (i = 1; i <= origNumChannels; i++) {
// retrieve the individual channels from the results, dissect their names, find channel numbers and imageIDs, and store them in parallel arrays
			selectWindow(tmpTitle+" #"+i);
			iArr[i-1]=getImageID();
			t=getTitle();
			tbn=split(t," ");
			tbn=tbn[0];
			//debugger(iArr[i-1], LOG);
			//debugger(t, LOG);
			hi=indexOf(t, "#");
			c=substring(t, hi+1);
			cArr[i-1]=c;
		}
		Array.print(iArr);
		Array.print(cArr);
// apply standard channel names (rename) on the basis of the data within the arrays.		
		for (i = 0; i < lengthOf(iArr); i++) {
			outName="C"+cArr[i]+"-"+tbn;
			debugger(iArr[i], LOG);
			debugger(getTitle(), LOG);
			debugger(outName, LOG);
			selectImage(iArr[i]);
			rename(outName);
		}
// some 'echo'
		list = getList("image.titles");
		Array.print(list);
// merge channels and rename to original name
		//mergeChannels(tmpTitle, origNumChannels);
		params=tmpTitle+"|"+origNumChannels;
		runMacro(MERGECHANNELS_FMAC, params);
		rename(title);
//		close("\\Others");
	} else {
		debugger(getTitle+": no deinterleaving necessary", LOG);
	}
}
