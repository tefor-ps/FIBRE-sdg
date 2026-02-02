print("\\Clear");
close("\\Others");
//run("Close All");
//open("//wsl.localhost/Ubuntu-22.04/DATA/tps/labdata/projects/M23-439-DR/231004DCa_3097a_5dpf_M23-439-IT_256_Nh_merge-fsdb/231004DCa_3097a_5dpf_M23-439-IT_256_Nh_merge.nd2");
//open("E:/stageTheo/DATA/yourTeamName/labdata/projects/TA-220-DR/211203Fa_2723a_6dpf_TA-220-DR_512_N_merge-fsdb/211203Fa_2723a_6dpf_TA-220-DR_512_N_merge.nd2");
//selectImage("211203Fa_2723a_6dpf_TA-220-DR_512_N_merge.nd2");
//run("Channels Tool...");

debuglevel=1;

title=split(getTitle(), "/");
title=title[lengthOf(title)-1];
rename(title);
IID=getImageID();
getDimensions(imgw, imgh, imgc, imgs, imgf);
print("Image dimensions:", imgw, imgh, imgc, imgs, imgf);
//dir=replace(getDirectory("image"),"\\","/");
dir=replace(getInfo("image.directory"),"\\","/");
tmp=split(title, ".");
suff=tmp[lengthOf(tmp)-1];
bn=replace(title, "."+suff, "");
if (matches(dir, ".*secData.*") == 1) {
	outdir=dir;
} else {
	//outdir=dir+"/"+bn+"-secData";
	outdir=makeOutDir();
}
print(outdir);
Property.set("CompositeProjection", "Sum");
Stack.setDisplayMode("composite");
//correctColors();

if ( imgs == 3 ){
	unmix23();
	IID=getImageID();
}

cropToSpecimen(IID, "crp", 1);
IID=getImageID();
saveAndExport("crp");
selectImage(IID);

cropToHead();
getDimensions(w, h, c, s, f);
pad=10;
run("Canvas Size...", "width="+w+pad+" height="+h+pad+" position=Center zero");
saveAndExport("head");

//run("Close All");
run("Collect Garbage");

function unmix23(){
	if (debuglevel > 0) { print("unmix23", getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	run("Select None");
	rename("UNMIX");
	run("Split Channels");
	selectImage("C3-UNMIX");
	run("Duplicate...", "title=REF duplicate");
	//run("Divide...", "value=2 stack");
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
//	close();
	selectImage(iid);
}

function correctColors(){
	if (debuglevel > 0) { print("correctColors", getTitle()); }
	if (debuglevel > 1) { waitForUser; }
//	colArr=newArray("Grey", "Cyan", "Magenta", "Yellow", "Red", "Green", "Blue");
	colArr=newArray("Grey", "Red", "Green", "Blue", "Cyan", "Magenta", "Yellow");
	if (imgc == 1){
		run(colArr[0]);
	} else {
		for (col = 1; col <= imgc; col++) {
			Stack.setChannel(col);
			//print(col, colArr[col]);
			run(colArr[col]);
			resetMinAndMax;
			//wait(10);
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
	//waitForUser;
	
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
	//print(getTitle(), getImageID());
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
		//makeMIP(suff);
	}
	close("*nrrd");
}

function fuseChannels(iid){
	if (debuglevel > 0) { print("fuseChannels", iid, getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	run("Z Project...", "projection=[Max Intensity]");
	tid=getImageID();
	selectImage(tid);
	if (imgc >1) {
		rename("FUSECHANNELS");
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
	
//	setAutoThreshold("Default dark no-reset");
	th=getBg(TID);
	setThreshold(th, 65535, "raw"); //TODO: make this 32bit-save
	getThreshold(lower, upper);
	if (debuglevel > 0) { print("threshold:",lower, upper); }

//	run("Create Selection");
//	run("Enlarge...", "enlarge=-2 pixel");
//	run("Enlarge...", "enlarge=2 pixel");
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
	//waitForUser;
	close("FINDHEAD*");
	selectImage(iid);
	run("Select None");
	return side;
}

function cropToHead(){
	if (debuglevel > 0) { print("cropToHead", getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	getDimensions(w, h, c, s, f);
	makeRectangle(0, 0, w/3, h);
	run("Crop");
	iid=getImageID();
	cropToSpecimen(iid, "head", 0);
}

function makeOutDir(){
	if (debuglevel > 0) { print("makeOutDir", getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	indir=replace(getDirectory("image"),"\\", "/");
	outdir=indir+bn+"-secData";
	//print(outdir);
	
	if ( File.isDirectory(outdir) == 0 ){
		File.makeDirectory(outdir);
	}
	return outdir;
}

function getBg(iid){
	if (debuglevel > 0) { print("getBg", iid, getTitle()); }
	if (debuglevel > 1) { waitForUser; }
	selectImage(iid);
	getDimensions(w, h, c, s, f);
	if (debuglevel > 0) { print(w, h, c, s, f); }
	div=15;
	wi=floor(w/div);
	he=floor(h/div);
	if (debuglevel > 0) { print("wi:", wi, ", he,", he); }
	lux=newArray(0, w-wi, 0, w-wi);
	luy=newArray(0, 0, h-he, h-he);
	count=0;
	maxsum=0;
	for (i = 0; i < 4; i++) {
		makeRectangle(lux[i], luy[i], wi, he);
		//print(lux[i], luy[i], wi, he);
		//waitForUser;
		getStatistics(ar, me, mi, ma, st, histogram);
		maxsum=maxsum+ma;
		//print(maxsum);
		count=count+1;
	}
	m=maxsum/count;
	run("Select None");
//	bgmax=(m/2)*3;
	bgmax=(m/3)*4;
	if (debuglevel > 0) { print("Threshold:", bgmax); }
	return bgmax;
}

function getBiggestROI() { 
// function description

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