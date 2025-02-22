//version=0.11
print("\\Clear");
close("\\Others");

// the debuglevel adjusts the level of verbosity and interactivity
// 0 : very little output
// 1 : more output
// 2 : interactive, stops at the beginning of each function. 
debuglevel=0;

title=split(getTitle(), "/");
title=title[lengthOf(title)-1];
rename(title);
IID=getImageID();
getDimensions(imgw, imgh, imgc, imgs, imgf);
print("Image dimensions:", imgw, imgh, imgc, imgs, imgf);
dir=replace(getInfo("image.directory"),"\\","/");
tmp=split(title, ".");
suff=tmp[lengthOf(tmp)-1];
bn=replace(title, "."+suff, "");
if (matches(dir, ".*secData.*") == 1) {
	outdir=dir;
} else {
//	outdir=makeOutDir();
	outdir=makeOutDir(dir);
}
print(outdir);
Property.set("CompositeProjection", "Sum");
Stack.setDisplayMode("composite");

if ( imgs == 3 ){
	unmix23();
	IID=getImageID();
}

//========
// TOGGLES
//========
// TODO: read these from IJ.prefs
rotateToHorizontal_tog=1;

cropToSpecimen(IID, "crp", 1);
IID=getImageID();
saveAndExport("crp");
selectImage(IID);

cropToHead(IID);
getDimensions(w, h, c, s, f);
pad=10;
run("Canvas Size...", "width="+w+pad+" height="+h+pad+" position=Center zero");
saveAndExport("head");

//run("Close All");
run("Collect Garbage");

// ====================
// FUNCTION DEFINITIONS
// ====================

function unmix23(){
	if (debuglevel > 0) { print("unmix23", getTitle()); }
	if (debuglevel > 1) { waitForUser; }
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
	if (debuglevel > 1) { waitForUser; }
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

function makeMIP( suff){
	if (debuglevel > 0) { print("makeMIP", suff, getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	iid=getImageID();
	run("Z Project...", "projection=[Max Intensity]");
	correctColors();
	saveAs("PNG", outdir+"/"+bn+"."+suff+".mip.png");
	print(outdir+"/"+bn+"."+suff+".mip.png");
	selectImage(iid);
}

function correctColors(){
	if (debuglevel > 0) { print("correctColors", getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	colArr=newArray("Grey", "Red", "Green", "Blue", "Cyan", "Magenta", "Yellow");
	if (imgc == 1){
		run(colArr[0]);
	} else {
		for (col = 1; col <= imgc; col++) {
			Stack.setChannel(col);
			run(colArr[col]);
			resetMinAndMax;
		}
	}
}

function cropToSpecimen(iid, suff, fh){
	selectImage(iid);
	if (debuglevel > 0) { print("cropToSpecimen", iid, suff, fh, getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	
	cropToROI(iid);

	getDimensions(w, h, c, s, f);
	iid=getImageID();

	if (fh == 1) {
		side=findHead(iid);
		
		selectImage(iid);
		if (side == "B") {
			run("Rotate 90 Degrees Right");
		}
		if (side == "T") {
			run("Rotate 90 Degrees Left");
		}
		if (side == "R") {
			run("Rotate... ", "angle=180 grid=1 interpolation=Bilinear");
		}
		Stack.setSlice(1);
		run("Delete Slice", "delete=slice");
	} else {
		selectImage(iid);
	}
	
	deinterleave();
	
	correctColors();	
}

function saveAndExport(suff){
	if (debuglevel > 0) { print("saveAndExport", suff, getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	iid=getImageID();
	saveAs("Tiff", outdir+"/"+bn+"."+suff+".tif");
	print(outdir+"/"+bn+"."+suff+".tif");
	makeMIP(suff);
	exportNrrds(suff);
}	

function exportNrrds(suff){
	if (debuglevel > 0) { print("exportNrrds", suff, getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	run("Duplicate...", "title=NRRD duplicate");
	getDimensions(w, h, c, s, f);
	iid=getImageID();
	run("Split Channels");
	n=nImages;
	for (i = 1; i <= c ; i++) {
		outfile=outdir+"/C"+i+"-"+bn+"."+suff+".nrrd";
		if (debuglevel > 0) { 
			print(i, iid-i, outfile);
		} else {
			print(outfile);
		}
		selectImage(iid-i);
		run("Nrrd ... ", "nrrd="+outfile);
	}
	close("*nrrd");
}

function fuseChannels(iid){
	if (debuglevel > 0) { print("fuseChannels", iid, getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	run("Z Project...", "projection=[Max Intensity]");
	tid=getImageID();
	selectImage(tid);
	wait(100);
	getDimensions(w, h, c, s, f);
	if ((imgc > 1 ) && (c > 1)) {
		rename("FUSECHANNELS");
		//wait(100);
		//waitForUser;
		run("Split Channels");
		imageCalculator("Add create", "C1-FUSECHANNELS","C2-FUSECHANNELS");
		selectImage("Result of C1-FUSECHANNELS");
		rename("FUSECHANNELS");
		for (c = 2; c <= imgc; c++) {
			imageCalculator("Add", "FUSECHANNELS","C"+c+"-FUSECHANNELS");
		}
		run("Grays");
		close("C*");
	} else {
		run("Duplicate...", "title=FUSECHANNELS duplicate"); 
	}
	TID=getImageID();
	return TID;
}

function cropToROI(iid){
	if (debuglevel > 0) { print("cropToROI", iid, getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	
	if (imgc > 1){
		TID=fuseChannels(iid);
	} else {
		selectImage(iid);
		run("Duplicate...", "title=CROPTOROI");
		TID=getImageID();
	}
	
	selectImage(TID);
	resetMinAndMax();
	
	setAutoThreshold("Huang dark no-reset");
	wait(100);
	setAutoThreshold("Huang dark no-reset");
	wait(100);

	getThreshold(lower, upper);
	if (debuglevel > 0) { print("threshold:",lower, upper); }

	getBiggestROI();
	run("To Bounding Box");
	run("Enlarge...", "enlarge=20 pixel");
	
	selectImage(iid);
	run("Restore Selection");
	
	run("Crop");
	wait(100);
	getDimensions(w, h, c, s, f);
	close("CROPTOROI*");
	close("FUSECHANNELS");
	r=w+h;
	return r
}

function findHead(iid){
	if (debuglevel > 0) { print("findHead", iid, getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	frac=5;
	getDimensions(w, h, c, s, f);
	selectImage(iid);
	if (w>h) {
		selectImage(iid);
		makeRectangle(0, 0, w/frac, h);
		run("Duplicate...", "title=FINDHEAD-L duplicate");
		lh=cropToROI(getImageID());
		if (debuglevel > 0) { print("left height:", lh); }
		
		selectImage(iid);
		makeRectangle(w-w/frac, 0, w/frac, h);
		run("Duplicate...", "title=FINDHEAD-R duplicate");
		rh=cropToROI(getImageID());
		if (debuglevel > 0) { print("right height:",rh); }
		if (rh>lh){
			side="R";
		} else {
			side="L";
		}
	} else {
		selectImage(iid);
		makeRectangle(0, 0, w, h/frac);
		run("Duplicate...", "title=FINDHEAD-T duplicate");
		tw=cropToROI(getImageID());
		if (debuglevel > 0) { print("top width:",tw); }
		
		selectImage(iid);
		makeRectangle(0, h-h/frac, w, h/frac);
		run("Duplicate...", "title=FINDHEAD-B duplicate");
		bw=cropToROI(getImageID());
		if (debuglevel > 0) { print("bottom width:",bw); }
		if (tw>bw){
			side="T";
		} else {
			side="B";
		}
	}
	if (debuglevel > 0) { print(side); }
	close("FINDHEAD*");
	selectImage(iid);
	run("Select None");
	return side;
}

function cropToHead(iid){
	if (debuglevel > 0) { print("cropToHead", getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	selectImage(iid);
	getDimensions(w, h, c, s, f);
	makeRectangle(0, 0, w/3, h);
	run("Crop");
	iid=getImageID();
	suffix="head";
	close("\\Others");

	if (rotateToHorizontal_tog == 1) {
		suffix=rotateToHorizontal(iid, suffix);
		iid=getImageID();
	}
	if (debuglevel > 0) { print("suffix", suffix); }
	cropToSpecimen(iid, suffix, 0);
}

function makeOutDir(indir){
	if (debuglevel > 0) { print("makeOutDir", getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	//indir=replace(getDirectory("image"),"\\", "/");
	outdir=indir+"/"+bn+"-secData";
	
	if ( File.isDirectory(outdir) == 0 ){
		File.makeDirectory(outdir);
	}
	return outdir;
}

function getBiggestROI() { 
	if (debuglevel > 0) { print("getBiggestROI", iid, getTitle()); }
	if (debuglevel > 1) { waitForUser; }

	if (roiManager("size") > 0) {
	roiManager("Select", 0);
	roiManager("reset")
	}
	
	run("Select None");
	run("Create Selection");
	run("ROI Manager...");
	
	roiManager("Add");
	
	roiManager("Select", 0);
	roiManager("Split");
	roiManager("Select", 0);
	roiManager("Delete");
	roiManager("Select", 0);
	roiManager("Show None");
	
	biggest=0;
	for (i = 0; i < roiManager("size"); i++) {
		roiManager("Select", i);
		getStatistics(area, mean, min, max, std, histogram);
		if (area > biggest) {
			biggest=area;
			winnerIndex=i;
		}
	}
	roiManager("Select", winnerIndex);
}

function rotateToHorizontal(iid, suff){
	if (debuglevel > 0) { print("rotateToHorizontal", iid, getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	
	suff=suff+".rot";

	fuseChannels(iid);

	setAutoThreshold("Default dark no-reset");
	wait(100);
	setAutoThreshold("Default dark no-reset");
	wait(100);
	run("Create Selection");
	run("Fit Ellipse");
	run("Set Measurements...", "area mean min fit shape redirect=None decimal=3");
	run("Measure");
	
	angle=getResult("Angle", nResults-1);
	print("angle:",angle);
	
	if (angle<=90) {
		rotation=angle;	
	}else {
		rotation=angle-180;
	}	
	
	print("rotation:",rotation);
	close();
	

	selectImage(iid);
	run("Select None");
	run("Rotate... ", "angle="+rotation+" grid=1 interpolation=Bicubic  fill enlarge");
	
	writeTransformationMatrix(suff);
	return suff;
}

function writeTransformationMatrix(suff){
	if (debuglevel > 0) { print("writeTransformationMatrix", getTitle()); }
	if (debuglevel > 1) { waitForUser; }

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
	saveAs("Text", outdir+"/"+bn+"."+suff+".txt");
	print(outdir+"/"+bn+"."+suff+".txt");
}
