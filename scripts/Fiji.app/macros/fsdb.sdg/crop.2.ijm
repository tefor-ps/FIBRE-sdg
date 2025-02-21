open("E:/stageTheo/DATA/yourTeamName/labdata/projects/TA-220-DR/211203Fa_2723a_6dpf_TA-220-DR_512_N_merge-fsdb/211203Fa_2723a_6dpf_TA-220-DR_512_N_merge.nd2");
rename("211203Fa_2723a_6dpf_TA-220-DR_512_N_merge.nd2");
//run("Channels Tool...");
print("\\Clear");
close("\\Others");

title=split(getTitle(), "/");
title=title[lengthOf(title)-1];
rename(title);
IID=getImageID();
getDimensions(imgw, imgh, imgc, imgs, imgf);
//dir=replace(getDirectory("image"),"\\","/");
dir=replace(getInfo("image.directory"),"\\","/");
tmp=split(title, ".");
suff=tmp[lengthOf(tmp)-1];
bn=replace(title, "."+suff, "");
if (matches(dir, ".*secData.*") == 1) {
	outdir=dir;
} else {
	outdir=dir+"/"+bn+"-secData";
}
var TID="";

Property.set("CompositeProjection", "Sum");
Stack.setDisplayMode("composite");
//correctColors();

cropToSpecimen(IID, "crp", 1);

cropToHead();

run("Close All");
run("Collect Garbage");

function deinterleave(){
	print("deinterleave");
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

function makeMIP(){
	print("makeMIP");
	iid=getImageID();
	run("Z Project...", "projection=[Max Intensity]");
	correctColors();
	tbn=replace(getTitle(), ".tif", "");
	saveAs("PNG", outdir+"/"+bn+".mip.png");
	print(outdir+"/"+bn+".mip.png");
//	close();
	selectImage(iid);
}

function correctColors(){
	print("correctColors");
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
	print("cropToSpecimen", iid, suff, fh);
	
	cropToROI(iid);
	//waitForUser;

	close("tmp*");	
	
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
			run("Rotate 90 Degrees Right");
			run("Rotate 90 Degrees Right");
		}
		Stack.setSlice(1);
		run("Delete Slice", "delete=slice");
	}
	//waitForUser;

	deinterleave();
	
	correctColors();
	
	saveAs("Tiff", outdir+"/"+bn+"."+suff+".tif");
	print(outdir+"/"+bn+"."+suff+".tif");
	makeMIP();
	//run("Nrrd ... ", "nrrd="+outdir+"/"+bn+"."+suff+".nrrd");
	exportNrrds(suff);
}

function exportNrrds(suff){
	close("\\Others");
	iid=getImageID();
	run("Split Channels");
	n=nImages;
	for (i = 1; i <= n ; i++) {
		selectImage(iid+i);
		run("Nrrd ... ", "nrrd="+outdir+"/C"+i+"-"+bn+"."+suff+".nrrd");
	}
}

function fuseChannels(iid){
	print("fuseChannels", iid);
	selectImage(iid);
	if (imgc >1) {
		rename("tmp");
		run("Split Channels");
		imageCalculator("Add create", "C1-tmp","C2-tmp");
		selectImage("Result of C1-tmp");
		rename("tmp");
		for (c = 2; c <= imgc; c++) {
			imageCalculator("Add", "tmp","C"+c+"-tmp");
		}
		run("Grays");
		close("C*");
	} else {
		run("Duplicate...", "title=tmp duplicate");
	}
	TID=getImageID();
	return TID;
}

function cropToROI(iid){
	print("cropToROI", iid);
	run("Z Project...", "projection=[Max Intensity]");
	tid=getImageID();
	
	TID=fuseChannels(tid);
	
	selectImage(TID);
	resetMinAndMax();
	
	setAutoThreshold("Default dark no-reset");
	run("Create Selection");
	run("Enlarge...", "enlarge=-5 pixel");
	run("Enlarge...", "enlarge=5 pixel");
	run("To Bounding Box");
	run("Enlarge...", "enlarge=20 pixel");
	selectImage(iid);
	run("Restore Selection");
	run("Crop");
	wait(100);
}

function findHead(id){
	print("findHead", id);
	frac=4;
	getDimensions(w, h, c, s, f);
	selectImage(id);
	if (w>h) {
		selectImage(id);
		makeRectangle(0, 0, w/frac, h);
		run("Duplicate...", "title=tmp-L duplicate");
		cropToROI(id);
		getDimensions(w, lh, c, s, f);
		
		selectImage(id);
		makeRectangle(w-w/frac, 0, w/frac, h);
		run("Duplicate...", "title=tmp-R duplicate");
		cropToROI(id);
		getDimensions(w, rh, c, s, f);
		if (rh>lh){
			side="R";
		} else {
			side="L";
		}
	} else {
		selectImage(id);
		makeRectangle(0, 0, w, h/frac);
		run("Duplicate...", "title=tmp-T duplicate");
		cropToROI(id);
		getDimensions(tw, h, c, s, f);
		
		selectImage(id);
		makeRectangle(0, h-h/frac, w, h/frac);
		run("Duplicate...", "title=tmp-B duplicate");
		cropToROI(id);		
		getDimensions(bw, h, c, s, f);
		if (tw>bw){
			side="T";
		} else {
			side="B";
		}
	}
	print(side);
	//waitForUser;
	close("tmp*");
	return side;
}

function cropToHead(){
	print("cropToHead");
	getDimensions(width, height, channels, slices, frames);
	makeRectangle(0, 0, width/3, height);
	run("Crop");
	iid=getImageID();
	cropToSpecimen(iid, "head", 0);
}