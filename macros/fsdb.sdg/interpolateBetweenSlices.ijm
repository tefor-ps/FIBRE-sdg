var TID="";
var TID2="";

interactive=0;

title=getTitle();
bn=replace(title, ".tif", "");
bn=split(title, ".");
bn=bn[0];

getDimensions(imgw, imgh, imgc, imgs, imgf);

dir=replace(getInfo("image.directory"),"\\","/");
if (matches(dir, ".*secData.*") == 1) {
	outdir=dir;
} else {
	//outdir=dir+"/"+bn+"-secData";
	outdir=makeOutDir();
}

print("\\Clear");
close("\\Others");

getVoxelSize(vw, vh, vd, unit);
if ( floor(vd/vw) > 1){
	insertSlices();
	saveAs("Tiff", outdir+"/"+bn+".iso.tif");
	print(outdir+"/"+bn+".iso.tif");
	makeMIP();
	run("Nrrd ... ", "nrrd="+outdir+"/"+bn+".iso.nrrd");
}


function interpol(sl) {
	selectImage(TID);
	Stack.setSlice(sl);
	a=sl;
	na="img"+a;
	b=sl+1;
	nb="img"+b;
	//print(na,nb);
	Stack.setSlice(a);	
	run("Duplicate...", "title="+na);
	selectImage(TID);
	Stack.setSlice(b);
	run("Duplicate...", "title="+nb);
	imageCalculator("Average create", na, nb);
	TID2=getImageID();
	run("Select All");
	run("Copy");
	close();
	close("img*");
}

function insertSlices(){	
	IID=getImageID();
	print(IID);
	
	getDimensions(width, height, channels, slices, frames);
	print(width, height, channels, slices, frames);
	getVoxelSize(vw, vh, vd, unit);
	
	if (channels > 1){
		run("Split Channels");
	}

	setBatchMode(true);
	for (c = 1; c <=channels; c++) {
		if (channels > 1) {
			selectImage(IID-c);
			TID=getImageID();
		} else {
			TID=IID;
		}
		i=1;

		print(c);
//		while (i<=2*slices-1) {
		for (i = 1; i < (2*slices-1); i+=2) {
	
			selectImage(TID);
//			string="channel: "+c+", slice: "+i+", name: "+getTitle();
			string="channel: "+c+", slice: "+i;
			print("\\Update:"+string);
			Stack.setSlice(i);
			interpol(i);
			//selectImage(TID2);
			//close();
			//close("\\Others");
			selectImage(TID);
			Stack.setSlice(i);
			run("Add Slice");
	//		wait(100);
			run("Paste");
			run("Select None");
//			i=i+2;
		}
		setVoxelSize(vw, vh, vd/2, unit);
		//setBatchMode("exit and display");
	}	
	setBatchMode(false);
	
	if (channels > 1){
		run("Merge Channels...", "c1=C1-"+title+" c2=C2-"+title+" c3=C3-"+title+" create");
	}
	getVoxelSize(vw, vh, vd, unit);
	print(vw, vh, vd, unit);
// for interactive use.
	if (interactive == 1 ){
		waitForUser("save?", "Do you want to save the result?\nVoxelSize: "+vw+" x "+vh+" x "+vd+".");
	} else {
	//	getVoxelSize(vw, vh, vd, unit);
		if ( floor(vd/vw) > 1){
			insertSlices();
		}
	}
}

function makeMIP(){
	iid=getImageID();
	run("Z Project...", "projection=[Max Intensity]");
	correctColors();
	tbn=replace(getTitle(), ".tif", "");
	saveAs("PNG", outdir+"/"+tbn+".mip.png");
	print(outdir+"/"+tbn+".mip.png");
//	close();
	selectImage(iid);
}

function correctColors(){
//	colArr=newArray("Grey", "Cyan", "Magenta", "Yellow", "Red", "Green", "Blue");
	colArr=newArray("Grays", "Red", "Green", "Blue", "Cyan", "Magenta", "Yellow");
	if (imgc == 1){
		run(colArr[0]);
	} else {
		for (col = 1; col <= imgc; col++) {
			Stack.setChannel(col);
			print(col, colArr[col]);
			run(colArr[col]);
			resetMinAndMax;
			//wait(10);
		}
	}
}

function makeOutDir(){
	indir=replace(getDirectory("image"),"\\", "/");
	outdir=indir+bn+"-secData";
	print(outdir);
	
	if ( File.isDirectory(outdir) == 0 ){
		File.makeDirectory(outdir);
	}
	return outdir;
}