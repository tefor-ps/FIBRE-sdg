print("\\Clear");
run("Close All");
open("//wsl.localhost/Ubuntu-22.04/DATA/tps/labdata/projects/M23-439-DR/231004DCa_3097a_5dpf_M23-439-IT_256_Nh_merge-fsdb/231004DCa_3097a_5dpf_M23-439-IT_256_Nh_merge.nd2");
//open("E:/stageTheo/DATA/yourTeamName/labdata/projects/TA-220-DR/211203Fa_2723a_6dpf_TA-220-DR_512_N_merge-fsdb/211203Fa_2723a_6dpf_TA-220-DR_512_N_merge.nd2");
//selectImage("211203Fa_2723a_6dpf_TA-220-DR_512_N_merge.nd2");
//run("Channels Tool...");

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
Property.set("CompositeProjection", "Sum");
Stack.setDisplayMode("composite");
//correctColors();

cropToSpecimen(IID, "crp");

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

function makeMIP(suff){
	print("makeMIP", suff);
	iid=getImageID();
	run("Z Project...", "projection=[Max Intensity]");
	correctColors();
	tbn=replace(getTitle(), ".tif", "");
	saveAs("PNG", outdir+"/"+bn+"."+suff+".mip.png");
	print(outdir+"/"+bn+"."+suff+".mip.png");
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

function cropToSpecimen(iid, suff){
	print("cropToSpecimen", iid, suff, getTitle());
	print("iid", iid);
	run("Z Project...", "projection=[Max Intensity]");
	rename("tmp");
	run("Split Channels");
	imageCalculator("Add create", "C1-tmp","C2-tmp");
	selectImage("Result of C1-tmp");
	rename("tmp");
	imageCalculator("Add", "tmp","C3-tmp");
	run("Grays");
	TID=getImageID();
	close("C*");
	
	selectImage(TID);
	resetMinAndMax();
	
	setAutoThreshold("Default dark no-reset");
	run("Create Selection");
	run("Enlarge...", "enlarge=-2 pixel");
	run("Enlarge...", "enlarge=2 pixel");
	run("To Bounding Box");
	run("Enlarge...", "enlarge=20 pixel");
	selectImage(iid);
	run("Restore Selection");
	run("Crop");
	
	close("\\Others");
	
	getDimensions(w, h, c, s, f);
	if (h > w) {
		run("Rotate 90 Degrees Right");
		Stack.setSlice(1);
		run("Delete Slice", "delete=slice");
	}
	
	deinterleave();
	
	correctColors();
	
	saveAs("Tiff", outdir+"/"+bn+"."+suff+".tif");
	print(outdir+"/"+bn+"."+suff+".tif");
	makeMIP(suff);
	//run("Nrrd ... ", "nrrd="+outdir+"/"+bn+"."+suff+".nrrd");
	exportNrrds(suff);
}

function exportNrrds(suff){
	print("exportNrrds", suff);
	run("Duplicate...", "title=NRRD duplicate");
	getDimensions(w, h, c, s, f);
	//print(getTitle(), getImageID());
	iid=getImageID();
	run("Split Channels");
	n=nImages;
	for (i = 1; i <= c ; i++) {
		//print(i, iid-i);
		selectImage(iid-i);
		run("Nrrd ... ", "nrrd="+outdir+"/C"+i+"-"+bn+"."+suff+".nrrd");
	}
	close("*nrrd");
}

function cropToHead(){
	print("cropToHead");
	getDimensions(width, height, channels, slices, frames);
	makeRectangle(0, 0, width/3, height);
	run("Crop");
	iid=getImageID();
	cropToSpecimen(iid, "head");
}
