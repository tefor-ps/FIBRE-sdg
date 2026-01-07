//fsdb-rev-date: 240430
dbgName="clahe";
dbg=1; // debugging; active, when greater than 0
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
	INITLOG_FMAC=COREMACROS+"/fsdb.core.initLOG.ijm";
	DEBUG_FMAC=COREMACROS+"/fsdb.core.logger.ijm";
	CLAHE_IPSUFF=".cl";
	CLAHE_IPTOG=1;
	CLAHE_IPMAC="/CACHE/AJ-110-DR/fsdb23/scripts/Fiji.app/macros/fsdb.sdg/fsdb.sdg.clahe.ijm";
	DESP_IPTOG=0; // possible values: 0=off;1=despeckle pre clahe;2=despeckle pre and post clahe 
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
	INITLOG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initlog", COREMACROS+"/fsdb.core.initLOG.ijm");
	DEBUG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.debug", COREMACROS+"/fsdb.core.logger.ijm");
	CLAHE_IPSUFF=call("ij.Prefs.get", "fsdb.sdg.ipsuff.clahe", ".cl");
	CLAHE_IPTOG=call("ij.Prefs.get", "fsdb.sdg.iptog.clahe", 0);
	CLAHE_IPMAC=call("ij.Prefs.get", "fsdb.sdg.mac.clahe", SECDATAMACROS+"/fsdb.sdg.clahe.ijm");
	DESP_IPTOG=call("ij.Prefs.get", "fsdb.sdg.iptog.desp", 0);
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

// get ImageID
IID=getImageID();
selectImage(IID);

debugger("toggle: "+CLAHE_IPTOG, LOG);
debugger("despeckle: "+DESP_IPTOG, LOG);

title=getTitle();
if (interactive > 1 ){
	waitForUser(dbgName+" title: "+title);
}	
debugger(title, LOG);

if (CLAHE_IPTOG == 1) {
	ThreeDclahe();
// append clahe specific appendix	
	if(indexOf(title, CLAHE_IPSUFF) == -1) {
		rename(title+CLAHE_IPSUFF);
		debugger(title+CLAHE_IPSUFF, LOG);
	}
}
debugger("end", LOG);


function ThreeDclahe(){
	File.append(dbgName+": start", LOG);
		
	getDimensions(width, height, channels, slices, frames);
	run("Duplicate...", "title=CLAHE duplicate");
	
	setBatchMode(1);
//remove background speckles before CLAHE
	if(DESP_IPTOG > 0 && DESP_IPTOG < 3){
		if (slices > 1){
			run("Despeckle", "stack");
		} else {
			run("Despeckle");
		}
	}
// turn RGB images into three-channel-images	
	if (bitDepth() == 24) {
		run("Make Composite");
	}
// run CLAHE on each channel of each slice	
	for (slice=1; slice<=slices; slice++){
		Stack.setSlice(slice);
	}
	for (channel=1; channel <= channels; channel++){
		Stack.setChannel(channel);
		run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None* fast_(less_accurate) process_as_composite");
	}
}
//remove background speckles after CLAHE
if(DESP_IPTOG > 1){
	if (slices > 1){
		run("Despeckle", "stack");
	} else {
		run("Despeckle");
	}
}
setBatchMode(0);