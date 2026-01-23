//fsdb-rev-date: 260114

//print("\\Clear");

if (getArgument() == "") {
	title=getInfo("image.filename");
	ft=replace(title, ".*\\.", "\\.");
	//print(suff);
	bn=replace(title, ft, "");
	//print(bn);
	outSuff="-crp";
} else {
	outSuff=getArgument();
}

dbgName="crop";
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
SAVENRRD_MAC=SDGMACROS+"/fsdb.sdg.saveNrrd.ijm";
SAVETIF_MAC=SDGMACROS+"/fsdb.sdg.saveTif.ijm";
SAVEPNG_MAC=SDGMACROS+"/fsdb.sdg.savePng.ijm";
MIP_MAC=SDGMACROS+"/fsdb.sdg.mip.ijm";

// prepare parameters for logging
LOG=runMacro(INITLOG_FMAC, dbgName);

function debugger(str, LOG){
	if (dbg > 0){
		str=dbgName+dbg+": "+str+" "+LOG;
		runMacro(DEBUG_FMAC, str);
		dbg++;
	}
}

//print("\\Clear");
debugger("start", LOG);
//==== fsdb-end ====

close("\\Others");

// the debuglevel adjusts the level of verbosity and interactivity
// 0 : very little output
// 1 : more output
// 2 : logging enabled
// 3 : interactive, stops at the beginning of each function
// 4 : interactive with a lot of output - for debugging
debuglevel=0;

//========
// LOCALLY CONFIGURED PARAMETERS
//========
padding=20;
wt=100;
//========
// DEFAULT VALUES OF PARAMETERS & TOGGLES
//========
if (matches(outSuff, ".*head.*") == 1) {
	findHead_tog=1;
	if (matches(outSuff, ".*rot.*") == 1) {
		rotateToHorizontal_tog=1;
	} else {
		rotateToHorizontal_tog=0;
	}
} else {
	findHead_tog=0;
	rotateToHorizontal_tog=0;
}
debugger("findHead_tog: "+findHead_tog, LOG);
debugger("rotateToHorizontal_tog: "+rotateToHorizontal_tog, LOG);

makeTS();

//========
// 'MAIN'
//========
// isolate and apply filename of/to open image, extract basename and original suffix
title=split(getInfo("image.filename"), "/");
title=title[lengthOf(title)-1];
rename(title);
tmp=split(title, ".");
origft=tmp[lengthOf(tmp)-1];
bn=replace(title, "."+origft, "");
// define imageID (IID)
IID=getImageID();
// define work directory and output directory from image location.
dir=replace(getInfo("image.directory"),"\\","/");
if (matches(dir, ".*secData.*") == 1) {
	outdir=dir;
} else {
	outdir=makeOutDir(dir);
}
print(outdir);
// get dimensions
getDimensions(imgw, imgh, imgc, imgs, imgf);
print("Image dimensions:", imgw, imgh, imgc, imgs, imgf);
getVoxelSize(vwidth, vheight, vdepth, vunit);
print("Voxel dimensions:", vwidth, vheight, vdepth, vunit);
// adjust visualization
if (is("composite") == 1){
	Property.set("CompositeProjection", "Sum");
	Stack.setDisplayMode("composite");
}
// subtract channnel3 from channel2 
if ( imgc == 3 ){
	unmix23();
	IID=getImageID();
}

// crop to specimen (and rotate head to the left)
//cropToSpecimen(IID, "crp", findHead_tog);
cropToSpecimen(IID, "crp", 1);
// crop along z-axis
run("Reslice [/]...", "output=1.000 start=Top avoid");
DID=getImageID();
cropToSpecimen(DID, "crp", 0);
run("Reslice [/]...", "output=1.000 start=Top avoid");
D2D=getImageID();
selectImage(DID);
close();
selectImage(IID);
close();
selectImage(D2D);
IID=getImageID();

// save result as tif
	saveAsTif(".crp");
// save as nrrd	
	//exportNrrds(outSuff);
// reset IID to cropped image
IID=getImageID();
selectImage(IID);

// crop to head (left 1/3 of specimen)
if (findHead_tog == 1 ) {
	cropToHead(IID);
}

getDimensions(w, h, c, s, f);

makeTS();

//debugger(outPath, LOG);
debugger("end", LOG);
//run("Quit");


// ====================
// FUNCTION DEFINITIONS
// ====================

function makeTS(){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	//print(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	//print(IJ.pad(substring(year,2,4),2), IJ.pad(month,2), IJ.pad(dayOfMonth,2), IJ.pad(hour,2), IJ.pad(minute,2), IJ.pad(second,2), IJ.pad(msec,2));
	y=toString(IJ.pad(substring(year,2,4),2));
	m=toString(IJ.pad(month,2));
	d=toString(IJ.pad(dayOfMonth,2));
	h=toString(IJ.pad(hour,2));
	M=toString(IJ.pad(minute,2)); 
	s=toString(IJ.pad(second,2));
	ts=y+m+d+"-"+h+M+s;
	//print(ts);
	//if (debuglevel > 1) { File.append(ts, LOG); }
	if (debuglevel > 1) { debugger(ts, LOG); }
}

function unmix23(){
	if (debuglevel > 0) { print("unmix23", getTitle()); }
	if (debuglevel > 1) { debugger("unmix23", LOG); }
	if (debuglevel > 2) { waitForUser; }
	run("Select None");
	rename("UNMIX");
	run("Split Channels");
	selectImage("C3-UNMIX");
	run("Duplicate...", "title=REF duplicate");
	imageCalculator("Subtract stack", "C2-UNMIX", "REF");
	close("REF");
	run("Merge Channels...", "c1=C1-UNMIX c2=C2-UNMIX c3=C3-UNMIX create");
	rename(title);
}

function deinterleave(){
	if (debuglevel > 0) { print("deinterleave", getTitle()); }
	if (debuglevel > 1) { debugger("deinterleave", LOG); }
	if (debuglevel > 2) { waitForUser; }
	getDimensions(w, h, c, s, f);
	if (imgc != c){
		print("deinterleaving.");
		run("Deinterleave", "how="+imgc);
		if (imgc == 2){
			run("Merge Channels...", "c1=["+title+" #1] c2=["+title+" #2] create ignore");
		} 
		if (imgc == 3) {
			run("Merge Channels...", "c1=["+title+" #1] c2=["+title+" #2] c3=["+title+" #3] create ignore");	
		}
		if (imgc == 4) {
			run("Merge Channels...", "c1=["+title+" #1] c2=["+title+" #2] c3=["+title+" #3] c4=["+title+" #4] create ignore");
		}
	}
}

function cropToSpecimen(iid, suff, fh){
	selectImage(iid);
	if (debuglevel > 0) { print("cropToSpecimen", iid, suff, fh, getTitle()); }
	if (debuglevel > 1) { debugger("cropToSpecimen "+iid+" "+suff+" "+fh , LOG); }
	if (debuglevel > 2) { waitForUser; }
// find and crop to biggest piece of specimen in the open image
	cropToROI(iid);
// update imageID and dimensions to match the cropped image. 
	getDimensions(w, h, c, s, f);
	iid=getImageID();
// crop to head
	if (fh == 1) {
// find position of head in image
		side=findHead(iid);
// rotate image to have the head point to the left of the image
		selectImage(iid);
		if (side == "B") {
			// head towards the bottom of the image
			run("Rotate 90 Degrees Right");
		}
		if (side == "T") {
			// head towards the top of the image
			run("Rotate 90 Degrees Left");
		}
		if (side == "R") {
			// head towards the right side of the image
			run("Rotate... ", "angle=180 grid=1 interpolation=Bilinear");
		}
// delete the first slice of the image as it (often) contains false data
		Stack.setSlice(1);
		run("Delete Slice", "delete=slice");
	} else {
		selectImage(iid);
	}
// sometimes channels become interleaved during processing; repair channels	
	deinterleave();
}

function saveAsTif(suff){
	if (debuglevel > 0) { print("saveAsTif", suff, getTitle()); }
	if (debuglevel > 1) { debugger("saveAsTif "+suff, LOG); }
	if (debuglevel > 2) { waitForUser; }
	iid=getImageID();
// save result as tif
	op=outdir+"/"+bn+suff+".tif";
	runMacro(SAVETIF_MAC, op);
	debugger(op, LOG);
	makeMIP(suff);
	selectImage(iid);
}

function makeMIP(suff){
	if (debuglevel > 0) { print("makeMIP", suff, getTitle()); }
	if (debuglevel > 1) { debugger("makeMIP "+suff, LOG); }
	if (debuglevel > 2) { waitForUser; }
	iid=getImageID();
	// make maximum intensity projection and save as png
	runMacro(MIP_MAC, suff+".mip");
	op=outdir+"/"+bn+suff+".mip.png";
	runMacro(SAVEPNG_MAC, op);
	debugger(op, LOG);
	selectImage(iid);
}
function exportNrrds(suff){
	if (debuglevel > 0) { print("exportNrrds", suff, getTitle()); }
	if (debuglevel > 1) { debugger("exportNrrds "+suff, LOG); }
	if (debuglevel > 2) { waitForUser; }
	iid=getImageID();
	op=outdir+"/"+bn+suff+".nrrd";
	runMacro(SAVENRRD_MAC, op);
	selectImage(iid);
	debugger(op, LOG);
}

function fuseChannels(iid){
	if (debuglevel > 0) { print("fuseChannels", iid, getTitle()); }
	if (debuglevel > 1) { debugger("fuseChannels "+iid, LOG); }
	if (debuglevel > 2) { waitForUser; }
	selectImage(iid);
	if (debuglevel > 0) {print("fuseChannels", getImageID(), getTitle()); }
	run("Z Project...", "projection=[Max Intensity]");
	tid=getImageID();
	selectImage(tid);
	if (debuglevel > 0) {print("fuseChannels", getImageID(), getTitle());}
	wait(wt);
	getDimensions(w, h, c, s, f);
	if (debuglevel > 0) {print(w, h, c, s, f);}
	//waitForUser;
	if ((imgc > 1 )) {
		rename("FUSECHANNELS");
	if (debuglevel > 0) {print("fuseChannels", getImageID(), getTitle());}
		run("Split Channels");
		imageCalculator("Add create", "C1-FUSECHANNELS","C2-FUSECHANNELS");
		selectImage("Result of C1-FUSECHANNELS");
	if (debuglevel > 0) {print("fuseChannels", getImageID(), getTitle());}
		rename("FUSECHANNELS");
		for (c = 2; c <= imgc; c++) {
			imageCalculator("Add", "FUSECHANNELS","C"+c+"-FUSECHANNELS");
			rename("FUSECHANNELS");
		}
		run("Grays");
		close("C*");
	} else {
		run("Duplicate...", "title=FUSECHANNELS duplicate"); 
	if (debuglevel > 0) {print("fuseChannels", getImageID(), getTitle());}
	}
	TID=getImageID();
	return TID;
}

function cropToROI(iid){
	if (debuglevel > 0) { print("cropToROI", iid, getTitle()); }
	if (debuglevel > 1) { debugger("cropToROI "+iid, LOG); }
	if (debuglevel > 2) { waitForUser; }
// to avoid missing any signal, fuse all signals of all channels into one --> TID
	TID=fuseChannels(iid);
	selectImage(TID);
// detect specimen by auto-thresholding
	resetMinAndMax();
	setAutoThreshold("Huang dark no-reset");
	wait(wt);
	setAutoThreshold("Huang dark no-reset");
	if (debuglevel > 2) { waitForUser; } else { wait(wt);}
// get threshole parameters
	getThreshold(lower, upper);
	if (debuglevel > 0) { print("threshold:",lower, upper); }
// find the biggest ROI only
	getBiggestROI();
// turn biggest ROI into bounding box
	run("To Bounding Box");
// and increase bounding box size by 'padding' pixels to ensure, that all of the specimen is within
	run("Enlarge...", "enlarge="+padding+" pixel");
// close temporary image
	close("FUSECHANNELS");
// apply bounding box to original image
	selectImage(iid);
	if (debuglevel > 2) { getTitle(); waitForUser; } else { wait(wt);}
	if (debuglevel > 0) {
		getDimensions(w, h, c, s, f);
		print("before crop:", w, h, c, s, f);
	}
	run("Restore Selection");
// crop to bounding box	
	run("Crop");
	if (debuglevel > 0) {
		getDimensions(w, h, c, s, f);
		print("after crop:", w, h, c, s, f);
	}
	
	if (debuglevel > 2) { waitForUser; } else { wait(wt);}
	getDimensions(w, h, c, s, f);

	r=w*h;
	if (debuglevel > 2) { print("region:", r);}
	return r
}

function findHead(iid){
// this function detects the head of the specimen by measuring the width of a part
// of the specimen (after thresholding); the head is wider than the tail. 
// this works only on complete (fish) specimens.
	if (debuglevel > 0) { print("findHead", iid, getTitle()); }
	if (debuglevel > 1) { debugger("findHead "+iid, LOG); }
	if (debuglevel > 2) { waitForUser; }
// define fraction of longside of image.
	frac=5;
	getDimensions(w, h, c, s, f);
	selectImage(iid);
	if (w>h) {
// when the image is wider, than it is high
		selectImage(iid);
// search in left end of the image
		makeRectangle(0, 0, w/frac, h);
		run("Duplicate...", "title=FINDHEAD-L duplicate");
		lh=cropToROI(getImageID());
		if (debuglevel > 0) { print("left height:", lh); }
// search in right end of the image
		selectImage(iid);
		makeRectangle(w-w/frac, 0, w/frac, h);
		run("Duplicate...", "title=FINDHEAD-R duplicate");
		rh=cropToROI(getImageID());
		if (debuglevel > 0) { print("right height:",rh); }
// evaluate measurements
		if (rh>lh){
			side="R";
		} else {
			side="L";
		}
	} else {
// when the image is higher than wide
		selectImage(iid);
// search in the upper end
		makeRectangle(0, 0, w, h/frac);
		run("Duplicate...", "title=FINDHEAD-T duplicate");
		tw=cropToROI(getImageID());
		if (debuglevel > 0) { print("top width:",tw); }
// search in the lower end
		selectImage(iid);
		makeRectangle(0, h-h/frac, w, h/frac);
		run("Duplicate...", "title=FINDHEAD-B duplicate");
		bw=cropToROI(getImageID());
		if (debuglevel > 0) { print("bottom width:",bw); }
// evaluate measurements
		if (tw>bw){
			side="T";
		} else {
			side="B";
		}
	}
	if (debuglevel > 0) { print(side); }
// clean-up
	close("FINDHEAD*");
	selectImage(iid);
	run("Select None");
	return side;
}

function cropToHead(iid){
// select and crop to the left 1/3 of the original image
// ( this part of the image was emperically determined to contain the head )
	if (debuglevel > 0) { print("cropToHead", iid, getTitle()); }
	if (debuglevel > 1) { debugger("cropToHead "+iid, LOG); }
	if (debuglevel > 2) { waitForUser; }
	selectImage(iid);
	getDimensions(w, h, c, s, f);
	makeRectangle(0, 0, w/3, h);
	run("Crop");
// zero-pad cropped surface/end of image
	getDimensions(w, h, c, s, f);
	run("Canvas Size...", "width="+w+padding+" height="+h+" position=Center-Left zero");
// clean-up
	iid=getImageID();
	close("\\Others");
// save result
	suffix="-head";
// save result as tif	
	saveAsTif(suffix);
// save as nrrd	
	exportNrrds(suffix);
// align body-axis with image coordinate system (as much as possible)
	if (rotateToHorizontal_tog == 1) {
		suffix=rotateToHorizontal(iid, suffix);
		iid=getImageID();
		if (debuglevel > 0) { print("suffix", suffix); }
		cropToSpecimen(iid, suffix, 0);
		saveAsTif(suffix);
	}
}

function makeOutDir(indir){
// define and create output directory
	if (debuglevel > 0) { print("makeOutDir", indir); }
	if (debuglevel > 1) { debugger("makeOutDir", LOG); }
	if (debuglevel > 2) { waitForUser; }
	outdir=indir+"/"+bn+"-secData";
	if ( File.isDirectory(outdir) == 0 ){
		File.makeDirectory(outdir);
	}
	return outdir;
}

function getBiggestROI() { 
// detect biggest ROI after thresholding
	if (debuglevel > 0) { print("getBiggestROI", iid, getTitle()); }
	if (debuglevel > 1) { debugger("getBiggestROI "+iid, LOG); }
	if (debuglevel > 2) { waitForUser; }
// reset ROI Manager
	if (roiManager("size") > 0) {
		roiManager("Select", 0);
		roiManager("reset")
	}
// reset selection
	run("Select None");
// create selection from thresholding result
	run("Create Selection");
// add selections to ROI Manager
	run("ROI Manager...");
	roiManager("Add");
// break disconnected elements of ROI into individual ROIs
	roiManager("Select", 0);
	if (selectionType() == 9){
		roiManager("Split");
		roiManager("Select", 0);
		roiManager("Delete");
	}
	roiManager("Select", 0);
	roiManager("Show None");
// select biggest ROI from the list of ROIs
	biggest=0;
	for (i = 0; i < roiManager("size"); i++) {
		roiManager("Select", i);
		getStatistics(area, mean, min, max, std, histogram);
		if (debuglevel > 3) { print(i, area, mean, min, max, std); }
		if (area > biggest) {
			biggest=area;
			winnerIndex=i;
		}
	}
	if (debuglevel > 2) { print("biggest ROI:", winnerIndex, biggest);}
// select biggest ROI
	roiManager("Select", winnerIndex);
}

function rotateToHorizontal(iid, suff){
// align body axis (of head) to coordinate system (roughly pre-align for image registration)
	if (debuglevel > 0) { print("rotateToHorizontal", iid, getTitle()); }
	if (debuglevel > 1) { debugger("rotateToHorizontal "+iid, LOG); }
	if (debuglevel > 2) { waitForUser; }
	
	suff=suff+".rot";
selectImage(iid);
	if (debuglevel > 0) {print("rotateToHorizontal", getImageID(), getTitle());}
// fuse all signals of all channels into one --> TID
	TID=fuseChannels(iid);
	selectImage(TID);
// auto-threshold specimen 
	setAutoThreshold("Default dark no-reset");
	wait(wt);
	setAutoThreshold("Default dark no-reset");
	wait(wt);
// create ellipse from threshold-based selection
	run("Create Selection");
	run("Fit Ellipse");
// measure the angle of the longer axis of the ellipse	
	run("Set Measurements...", "area mean min fit shape redirect=None decimal=3");
	run("Measure");
	angle=getResult("Angle", nResults-1);
	print("angle:",angle);
// convert measured angle into degree of rotation 
	if (angle<=90) {
		rotation=angle;	
	} else {
		rotation=angle-180;
	}	
	print("rotation:",rotation);
// close temporary image
	selectImage(TID);
	close();
// apply rotation to original image
	selectImage(iid);
	if (debuglevel > 0) {print("rotateToHorizontal", getImageID(), getTitle());}
	run("Select None");
	run("Rotate... ", "angle="+rotation+" grid=1 interpolation=Bicubic  fill enlarge");
// log rotation as transformation matrix - for reproduction of result.
	writeTransformationMatrix(suff);
	selectImage(iid);
print("rotateToHorizontal", getImageID(), getTitle());
	return suff;
}

function writeTransformationMatrix(suff){
// write transforamtion parameters into log file  for re-use.
	if (debuglevel > 0) { print("writeTransformationMatrix", getTitle()); }
	if (debuglevel > 1) { debugger("writeTransformationMatrix", LOG); }
	if (debuglevel > 2) { waitForUser; }

	oneline=1;
	A=cos((PI*rotation)/180);
	B=sin((PI*rotation)/180);
	C=-sin((PI*rotation)/180);
	D=cos((PI*rotation)/180);
	if (debuglevel == 0) {
		print("\\Clear");
	}
	if (oneline == 1){
		print("transformation parameters of a rotation of "+rotation+" degrees:");
		print(A+" "+B+" 0 "+C+" "+D+" 0 0 0 1");
	} else {
		print("transformation matrix of a rotation of "+rotation+" degrees:");
		print(A+" "+B+" 0");
		print(C+" "+D+" 0");
		print("0 0 1");
	}
	selectWindow("Log");
	op=outdir+"/"+bn+suff+".txt";
	if (File.exists(op) == 1){
		File.append(A+" "+B+" 0 "+C+" "+D+" 0 0 0 1", op);
	} else {
		saveAs("Text", op);
	}
	print(op);
}
