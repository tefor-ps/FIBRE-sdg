//fsdb-rev-date: 260109

if (getArgument() == "") {
	suff=".sss";
} else {
	suff=getArgument();
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

dbgName="sssGen";
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
SDGMACROS=FSDBDIR+"/fsdb-sdg/macros/fsdb.sdg/";
SAVETIF_MAC=SDGMACROS+"/fsdb.sdg.saveTif.ijm";

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
// clean up
selectImage(IID);
	close("\\Others");
// define work directory and output directory from image location.
dir=replace(getInfo("image.directory"),"\\","/");
if (matches(dir, ".*secData.*") == 1) {
	outdir=dir;
} else {
	outdir=makeOutDir(dir);
}
print(outdir);

// get metadata of image
getDimensions(width, height, channels, slices, frames);
getVoxelSize(vwidth, vheight, vdepth, vunit);

// create and store stacks of substacks of heavy data
// fix display
if(channels > 1 || bitDepth() == 24 ){
	if (is("composite") == 0) {
		run("Make Composite");
	}
}

// function calls

makeSubstack(IID, "xy");
// clean up for further steps
selectImage(IID);
//	close("\\Others");
call("java.lang.System.gc");
call("java.lang.System.gc");

	debugger("Reslicing", LOG);
	run("Reslice [/]...", "output="+vwidth+" start=Left avoid");
	YZID=getImageID();
	makeSubstack(YZID, "yz");
	// clean up for further steps
	selectImage(IID);
	//	close("\\Others");
	call("java.lang.System.gc");
	call("java.lang.System.gc");
	selectImage(YZID);
	close();
	
	debugger("Reslicing", LOG);
	///run("Reslice [/]...", "output="+vdepth+" start=Top flip avoid");
	run("Reslice [/]...", "output="+vdepth+" start=Top avoid");
	XZID=getImageID();
	makeSubstack(XZID, "xz");
	// clean up for further macros
	selectImage(IID);
	//	close("\\Others");
	call("java.lang.System.gc");
	call("java.lang.System.gc");
	selectImage(XZID);
	close();
	
	debugger("end", LOG);

// function definitions
function makeOutDir(indir){
// define and create output directory
	outdir=dir+"/"+bn+"-secData";
	if ( File.isDirectory(outdir) == 0 ){
		File.makeDirectory(outdir);
	}
	return outdir;
}

function makeSubstack(ID, ax) {
	debugger("makeSubstack", LOG);
	getDimensions(width, height, channels, slices, frames);
	debugger(toString(width)+" "+toString(height)+" "+toString(channels)+" "+toString(slices)+" "+toString(frames), LOG);
	getVoxelSize(vwidth, vheight, vdepth, unit);
	debugger(toString(vwidth)+" "+toString(vheight)+" "+toString(vdepth)+" "+toString(unit), LOG);
	if(channels >1){
		if (is("composite")) {
			Stack.setDisplayMode("composite");
		}
	}	
	tech=newArray("Max", "Average");
	sssuff=newArray("mip", "aip");
	label=newArray("MAX", "AVG");
	for (t=0; t<lengthOf(tech); t++){
		selectImage(ID);
	//	close("\\Others");
		thickness=100;
		numOfSlices=floor(thickness/vdepth);
		debugger(toString(thickness)+" micron = "+toString(numOfSlices)+" slices.", LOG);
		debugger("start processing substacks", LOG);
	//	if (File.exists(dir+bn+".sss-"+ax+"."+sssuff[t]+"."+IJ.pad(thickness,3)+ft) < 1) {
			for (i=1;i<=slices; i+=numOfSlices){
//reset suffix for each substack				
				debugger(toString(i)+": "+tech[t], LOG);
				selectImage(ID);
				I=i+numOfSlices;
				debugger("i: "+i+", I: "+I+", slices: "+slices, LOG);
				selectImage(ID);
				if (slices < I){
				//	run("Make Substack...", "  slices="+i+"-"+slices);
					run("Z Project...", "start="+i+" stop="+slices+" projection=["+tech[t]+" Intensity]");
				} else {
				//	run("Make Substack...", "  slices="+i+"-"+I);
					run("Z Project...", "start="+i+" stop="+I+" projection=["+tech[t]+" Intensity]");
				}
// convert to RGB
				TID=getImageID();
				run("RGB Color");
				wait(10);
				selectImage(TID);
				close();
			}
// combine sub-stack-projections to stack
			run("Images to Stack", "name="+bn+"."+ax+"."+sssuff[t]+suff+"."+IJ.pad(thickness,3)+" title="+label[t]+"_ use ");
// save sack of substacks as tif
			op=outdir+fs+bn+"."+ax+suff+IJ.pad(thickness,3)"."+sssuff[t]+".tif";
			runMacro(SAVETIF_MAC, op);
	}
}


